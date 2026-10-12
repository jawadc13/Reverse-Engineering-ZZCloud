#!/usr/bin/env python3
"""Screensaver builder: one GLSL shader + a small JSON file -> a .scr.

zzCloud.scr is a single fragment shader ("Protean clouds") inside 17 MB of
statically linked Qt. This tool builds the same kind of screensaver from any
Shadertoy-style shader, on the shared Direct3D 11 framework in common/
(one render thread and device per monitor, flip-model vsync per monitor,
frame-rate cap, adaptive render scale, span/same/different multi-monitor
modes, OLED screen care, Themes & Effects). The result is ~1 MB.

Pipeline:  GLSL  --glslangValidator-->  SPIR-V  --spirv-cross-->  HLSL
           (embedded in savers/<name>/<name>.cpp, compiled by D3DCompile at
           start-up, so no shader blobs and no D3D SDK are needed to build).

Usage:
  python3 tools/ssbuild.py new <name> [--from shader.glsl] [--title "Title"]
  python3 tools/ssbuild.py build [<name> ...]     # all of shaders/* if none given
  python3 tools/ssbuild.py check <shader.glsl>    # just translate, print errors
  Options for build: --no-make, --arch x64|x86

Shader formats accepted (detected automatically):
  * Shadertoy:  void mainImage(out vec4 fragColor, in vec2 fragCoord)
  * Plain GLSL / zzCloud style:  void main() writing gl_FragColor, reading
    gl_FragCoord and uniforms iTime / iResolution / iWidth / iHeight.
Inputs available: iResolution, iTime, iTimeDelta, iFrame, iMouse (always 0),
iParam (vec4, the saver's own sliders 0..1, also by the names in saver.json).
Not supported: iChannel0-3 (textures / buffers) - generate noise procedurally.

Needs: glslangValidator and spirv-cross (apt install glslang-tools spirv-cross),
and MinGW-w64 for the final build (apt install g++-mingw-w64-x86-64).
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADERS = os.path.join(ROOT, 'shaders')
SAVERS = os.path.join(ROOT, 'savers')

BUILTINS = ['iResolution', 'iTime', 'iTimeDelta', 'iFrame', 'iMouse', 'iWidth', 'iHeight', 'iParam']

# Every shader is wrapped in this. The uniform block must match
# shaderkit::Inputs (common/shaderkit.h).
WRAP_HEAD = '''#version 450
layout(std140, binding = 0) uniform SaverInputs {
    vec3  iResolution;
    float iTime;
    vec4  iMouse;
    vec4  _ss_span;      // xy: this monitor's offset (Span mode), z: 1/render scale, w: target height
    vec4  iParam;
    float iTimeDelta;
    float _ss_frame;
    vec2  _ss_pad;
};
#define iFrame int(_ss_frame)
#define iWidth iResolution.x
#define iHeight iResolution.y
layout(location = 0) out vec4 _ss_out;
'''

# Shader coordinates are bottom-up desktop pixels, whatever the render scale.
FRAGCOORD = 'vec4((gl_FragCoord.x) * _ss_span.z + _ss_span.x, (_ss_span.w - gl_FragCoord.y) * _ss_span.z + _ss_span.y, gl_FragCoord.z, 1.0)'

WRAP_TAIL_SHADERTOY = '''
void main() {
    vec4 c = vec4(0.0, 0.0, 0.0, 1.0);
    mainImage(c, _ss_coord().xy);
    _ss_out = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
}
'''

WRAP_TAIL_PLAIN = '''
void main() {
    _ss_FragCoord = _ss_coord();
    _ss_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    _ss_main();
    _ss_out = vec4(clamp(_ss_FragColor.rgb, 0.0, 1.0), 1.0);
}
'''


class BuildError(Exception):
    pass


def tool(name):
    path = shutil.which(name)
    if not path:
        raise BuildError(f'{name} not found. Install it: apt install glslang-tools spirv-cross')
    return path


def wrap_glsl(src, params):
    """Turns a Shadertoy or plain shader into a self-contained GLSL 450 shader."""
    s = src.replace('\r\n', '\n').replace('\r', '\n')
    if re.search(r'\biChannel\d\b', s):
        raise BuildError('iChannel textures are not supported; use procedural noise instead')
    s = re.sub(r'^\s*#\s*version\b.*$', '', s, flags=re.M)
    s = re.sub(r'^\s*precision\s+\w+\s+\w+\s*;', '', s, flags=re.M)
    # Declarations of inputs the wrapper provides (zzCloud declares
    # iTime/iWidth/iHeight and builds iResolution from them).
    names = '|'.join(BUILTINS)
    s = re.sub(r'^\s*uniform\s+\w+\s+(%s)\s*(\[[^\]]*\])?\s*;[^\n]*$' % names, '', s, flags=re.M)
    s = re.sub(r'^\s*(?:vec[234]|float|int)\s+(%s)\s*=[^;]*;[^\n]*$' % names, '', s, flags=re.M)
    leftover = re.findall(r'^\s*uniform\s+[^;]*;', s, flags=re.M)
    if leftover:
        raise BuildError('unsupported uniform(s): ' + '; '.join(x.strip() for x in leftover))
    head = WRAP_HEAD
    for i, p in enumerate(params[:3]):
        head += '#define %s iParam.%s\n' % (p['name'], 'xyz'[i])
    head += 'vec4 _ss_coord() { return %s; }\n' % FRAGCOORD
    if re.search(r'\bvoid\s+mainImage\s*\(', s):
        return head + '#line 1\n' + s + WRAP_TAIL_SHADERTOY
    if re.search(r'\bvoid\s+main\s*\(\s*(void)?\s*\)', s):
        s = s.replace('gl_FragColor', '_ss_FragColor').replace('gl_FragCoord', '_ss_FragCoord')
        s = re.sub(r'\bvoid\s+main\s*\(\s*(void)?\s*\)', 'void _ss_main()', s)
        head += 'vec4 _ss_FragColor;\nvec4 _ss_FragCoord;\n'
        return head + '#line 1\n' + s + WRAP_TAIL_PLAIN
    raise BuildError('no mainImage(out vec4, in vec2) or main() found')


def glsl_to_hlsl(src, params, label='shader'):
    glsl = wrap_glsl(src, params)
    with tempfile.TemporaryDirectory() as d:
        frag = os.path.join(d, 'shader.frag')
        spv = os.path.join(d, 'shader.spv')
        out = os.path.join(d, 'shader.hlsl')
        with open(frag, 'w') as f:
            f.write(glsl)
        r = subprocess.run([tool('glslangValidator'), '-V', '-S', 'frag', frag, '-o', spv],
                           capture_output=True, text=True)
        if r.returncode:
            msg = (r.stdout + r.stderr).replace(frag, label)
            raise BuildError('GLSL errors (line numbers are in your shader):\n' + msg.strip())
        r = subprocess.run([tool('spirv-cross'), spv, '--hlsl', '--shader-model', '40', '--output', out],
                           capture_output=True, text=True)
        if r.returncode:
            raise BuildError('spirv-cross failed:\n' + r.stderr)
        return open(out).read()


def c_string(name, text):
    """Raw string literal, split into chunks every compiler accepts."""
    parts = []
    for i in range(0, len(text), 12000):
        parts.append('R"SS(' + text[i:i + 12000] + ')SS"')
    return 'static const char %s[] =\n%s;\n' % (name, '\n'.join(parts))


def wstr(s):
    return 'L"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


QUALITY = {'auto': 0, 'ultra': 1, 'high': 2, 'balanced': 3, 'performance': 4}
FPS = {30: 0, 45: 1, 60: 2, 90: 3, 120: 4, 0: 5, 'refresh': 5}
MONITORS = {'span': 0, 'same': 1, 'different': 2}


def saver_cpp(spec, hlsl):
    d = spec.get('defaults', {})
    q = QUALITY[d.get('quality', 'auto')]
    fps = FPS[d.get('fps', 60)]
    mon = MONITORS[d.get('monitors', 'span')]
    params = spec.get('params', [])[:3]
    sliders = ['{ L"Speed", L"Speed", %d, L"Slow", L"Fast" }' % int(d.get('speed', 50))]
    for p in params:
        sliders.append('{ %s, %s, %d, %s, %s }' % (wstr(p.get('label', p['name'])), wstr('P_' + p['name']),
                                                    int(p.get('default', 50)), wstr(p.get('low', '')), wstr(p.get('high', ''))))
    sp = spec.get('speed', {})
    return '''// %(name)s.cpp - GENERATED by tools/ssbuild.py from shaders/%(name)s/. Edit those, not this.
// %(title)s: %(description)s
#include "../../common/shaderkit.h"
#include "resource.h"

%(hlsl)s
static SimpleConfig g_cfg = {
    %(dlg)s,
    3, { { L"Render &quality:", L"Quality", %(q)d, L"Auto (adaptive)|Ultra (100%%)|High (75%%)|Balanced (50%%)|Performance (35%%)" },
         { L"&Frame-rate cap:", L"FpsCap", %(fps)d, L"30 fps|45 fps|60 fps|90 fps|120 fps|Monitor refresh" },
         { L"&Multiple monitors:", L"Monitors", %(mon)d, L"Span across all monitors|Same view on every monitor|Different view per monitor" } },
    %(ns)d, { %(sliders)s },
};
static shaderkit::NoMultisample s_noMsaa;

const wchar_t* RegistryName() { return %(reg)s; }
void LoadSettings() { SimpleLoad(g_cfg); }
void ShowConfigDialog(HWND parent) { SimpleShowDialog(parent, g_cfg); }
Scene* CreateScene() { return new shaderkit::ShaderScene(kShader, sizeof(kShader) - 1, g_cfg, %(smin)rf, %(smax)rf); }
''' % dict(name=spec['name'], title=spec['title'], description=spec.get('description', ''),
           hlsl=c_string('kShader', hlsl), dlg=wstr(spec['title'] + ' Settings'), q=q, fps=fps, mon=mon,
           ns=len(sliders), sliders=',\n          '.join(sliders), reg=wstr(spec.get('registry', spec['title'].replace(' ', ''))),
           smin=float(sp.get('min', 0.25)), smax=float(sp.get('max', 1.75)))


RC = '''#include <windows.h>
#include "resource.h"
#include "common.rc"

IDI_MAIN ICON "{name}.ico"

STRINGTABLE
BEGIN
    IDS_DESCRIPTION  "{title}"
END

VS_VERSION_INFO VERSIONINFO
 FILEVERSION {ver}
 PRODUCTVERSION {ver}
 FILEOS VOS_NT_WINDOWS32
 FILETYPE VFT_APP
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904B0"
        BEGIN
            VALUE "FileDescription", "{description}"
            VALUE "FileVersion", "{verdot}"
            VALUE "InternalName", "{file}"
            VALUE "OriginalFilename", "{file}.scr"
            VALUE "ProductName", "Shader Screensaver Builder"
            VALUE "ProductVersion", "{verdot}"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END
'''


def hexcol(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def write_ico(path, pixel, n=32):
    """Writes a 32-bit n x n .ico; pixel(x, y) -> (r, g, b, a), y down."""
    import struct
    xor = b''.join(struct.pack('BBBB', *(lambda c: (c[2], c[1], c[0], c[3]))(pixel(x, y)))
                   for y in range(n - 1, -1, -1) for x in range(n))   # BMP rows are bottom-up
    and_mask = b'\0' * (n * 4)
    hdr = struct.pack('<IiiHHIIiiII', 40, n, n * 2, 1, 32, 0, len(xor) + len(and_mask), 0, 0, 0, 0)
    img = hdr + xor + and_mask
    with open(path, 'wb') as f:
        f.write(struct.pack('<HHH', 0, 1, 1) + struct.pack('<BBBBHHII', n, n, 0, 0, 1, 32, len(img), 22) + img)


def write_icon(path, colors):
    """32x32 icon: a soft blob of colour (top) over a gradient (bottom)."""
    import math
    a, b = hexcol(colors[0]), hexcol(colors[1] if len(colors) > 1 else colors[0])

    def px(x, y):
        t = y / 31.0
        base = [int(a[i] * (1 - t) + b[i] * t) for i in range(3)]
        cx, cy = x - 15.5, y - 13
        blob = max(0.0, 1 - math.hypot(cx * 0.8, cy) / 11) ** 0.7
        blob += max(0.0, 1 - math.hypot(cx + 6, cy - 4) / 7) ** 0.7 * 0.8
        blob += max(0.0, 1 - math.hypot(cx - 7, cy - 5) / 6) ** 0.7 * 0.8
        blob = min(1.0, blob)
        col = [int(base[i] * (1 - blob) + 245 * blob) for i in range(3)]
        corner = max(abs(x - 15.5), abs(y - 15.5)) > 15.2
        return (*col, 0 if corner else 255)
    write_ico(path, px)


def load_spec(name):
    d = os.path.join(SHADERS, name)
    with open(os.path.join(d, 'saver.json')) as f:
        spec = json.load(f)
    spec.setdefault('name', name)
    if not re.fullmatch(r'[a-z][a-z0-9_]*', spec['name']):
        raise BuildError('name must be lower-case letters, digits and _: ' + spec['name'])
    spec.setdefault('title', name)
    for p in spec.get('params', []):
        if not re.fullmatch(r'[A-Za-z_]\w*', p['name']):
            raise BuildError('param name must be a GLSL identifier: ' + p['name'])
    spec['_dir'] = d
    return spec


def generate(spec):
    name = spec['name']
    src = open(os.path.join(spec['_dir'], spec.get('shader', 'shader.glsl'))).read()
    hlsl = glsl_to_hlsl(src, spec.get('params', []), spec.get('shader', 'shader.glsl'))
    out = os.path.join(SAVERS, name)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, name + '.cpp'), 'w') as f:
        f.write(saver_cpp(spec, hlsl))
    with open(os.path.join(out, 'resource.h'), 'w') as f:
        f.write('#pragma once\n#include "../../common/common_res.h"\n')
    ver = [int(x) for x in str(spec.get('version', '1.0.0')).split('.')] + [0, 0, 0]
    with open(os.path.join(out, name + '.rc'), 'w') as f:
        f.write(RC.format(name=name, title=spec['title'].replace('"', "'"),
                          description=spec.get('description', spec['title']).replace('"', "'"),
                          file=spec.get('file', spec['title'].replace(' ', '')),
                          ver=','.join(map(str, ver[:4])), verdot='.'.join(map(str, ver[:4]))))
    write_icon(os.path.join(out, name + '.ico'), spec.get('icon_colors', ['#4060c0', '#102040']))
    return name


def write_saver_list():
    names = sorted(n for n in os.listdir(SHADERS) if os.path.isfile(os.path.join(SHADERS, n, 'saver.json')))
    files = {}
    for n in names:
        spec = load_spec(n)
        files[n] = spec.get('file', spec['title'].replace(' ', ''))
    with open(os.path.join(ROOT, 'savers.mk'), 'w') as f:
        f.write('# GENERATED by tools/ssbuild.py: every saver in shaders/ and its output file name.\n')
        f.write('SAVERS = %s\n' % ' '.join(names))
        for n, fn in files.items():
            f.write('FILE_%s = %s\n' % (n, fn))


TEMPLATE = '''// %s - write a Shadertoy-style shader here.
// Inputs: iResolution, iTime, iTimeDelta, iFrame, and the sliders from
// saver.json by name (0..1). Coordinates are desktop pixels, so in Span mode
// the picture continues across monitors.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime * 0.3;
    vec3 col = 0.5 + 0.5 * cos(t + uv.xyx * (2.0 + 4.0 * hue) + vec3(0.0, 2.0, 4.0));
    col *= 0.6 + 0.4 * sin(10.0 * length(uv) - 2.0 * iTime);
    fragColor = vec4(col, 1.0);
}
'''


def cmd_new(args):
    d = os.path.join(SHADERS, args.name)
    if os.path.exists(d):
        raise BuildError(d + ' already exists')
    os.makedirs(d)
    title = args.title or args.name.replace('_', ' ').title()
    if args.src:
        shutil.copy(args.src, os.path.join(d, 'shader.glsl'))
        params = []
    else:
        with open(os.path.join(d, 'shader.glsl'), 'w') as f:
            f.write(TEMPLATE % title)
        params = [{'name': 'hue', 'label': 'Colour spread', 'default': 50, 'low': 'Narrow', 'high': 'Wide'}]
    spec = {
        'title': title,
        'description': title + ' Screen Saver',
        'shader': 'shader.glsl',
        'params': params,
        'defaults': {'quality': 'auto', 'fps': 60, 'monitors': 'span', 'speed': 50},
        'speed': {'min': 0.25, 'max': 1.75},
        'icon_colors': ['#4080e0', '#102040'],
    }
    with open(os.path.join(d, 'saver.json'), 'w') as f:
        json.dump(spec, f, indent=2)
    print('created', os.path.relpath(d, ROOT), '- edit shader.glsl and saver.json, then: python3 tools/ssbuild.py build', args.name)


def cmd_build(args):
    names = args.names or sorted(n for n in os.listdir(SHADERS) if os.path.isfile(os.path.join(SHADERS, n, 'saver.json')))
    failed = []
    for n in names:
        try:
            generate(load_spec(n))
            print('generated savers/%s' % n)
        except BuildError as e:
            failed.append(n)
            print('%s: %s' % (n, e), file=sys.stderr)
    write_saver_list()
    if failed:
        raise BuildError('failed: ' + ', '.join(failed))
    if not args.no_make:
        targets = ['build/%s.scr' % load_spec(n).get('file', load_spec(n)['title'].replace(' ', '')) for n in names]
        r = subprocess.run(['make', '-C', ROOT, '-j%d' % (os.cpu_count() or 2), 'ARCH=' + args.arch] + targets)
        if r.returncode:
            raise BuildError('make failed')
        for t in targets:
            print('built', t)


def cmd_check(args):
    hlsl = glsl_to_hlsl(open(args.file).read(), [], os.path.basename(args.file))
    print('OK: %d lines of HLSL' % hlsl.count('\n'))
    if args.verbose:
        print(hlsl)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('new', help='start a new saver in shaders/<name>')
    p.add_argument('name')
    p.add_argument('--from', dest='src', help='copy this GLSL file as the shader')
    p.add_argument('--title')
    p.set_defaults(fn=cmd_new)
    p = sub.add_parser('build', help='generate and compile savers')
    p.add_argument('names', nargs='*')
    p.add_argument('--no-make', action='store_true')
    p.add_argument('--arch', default='x64', choices=['x64', 'x86'])
    p.set_defaults(fn=cmd_build)
    p = sub.add_parser('check', help='translate a shader and report errors')
    p.add_argument('file')
    p.add_argument('-v', '--verbose', action='store_true')
    p.set_defaults(fn=cmd_check)
    args = ap.parse_args()
    try:
        args.fn(args)
    except BuildError as e:
        print('error:', e, file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
