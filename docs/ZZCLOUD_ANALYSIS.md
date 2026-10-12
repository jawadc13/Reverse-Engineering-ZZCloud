# zzCloud.scr: analysis

## Identity

| | |
|---|---|
| File | `zzCloud.scr`, 17.1 MB, SHA-256 `e1675d49f465f5ada71f15880552cdc8994d47acd0b843d767e868423f396201` |
| Format | PE32+ (x86-64) GUI, 11 sections incl. `.qtmetad`, `.CRT`, `.tls`; stripped |
| Toolchain | MinGW-w64 GCC 8.1.0 (linker 2.30, imports `msvcrt.dll`) |
| Framework | **Qt 5.15.1, static release build** (`Qt 5.15.1 (x86_64-little_endian-llp64 static release build; by GCC 8.1.0)`) |
| Built | `Oct 13 2020` (`__DATE__` string; PE timestamp 2020-10-14) |
| Version resource | ProductName `zzCloud`, OriginalFilename `zzCloud.scr`, version 0.0.0.0, no company |
| Author (About box) | "Written by Dr. Javier Lechuga" |

Almost all of the 17 MB is Qt: Widgets, Gui, the Windows platform plugin, image plugins (libwebp, ...), HarfBuzz, double-conversion and locale tables. The screensaver's own code is small.

## What it actually draws

The whole animation is **one fragment shader**, embedded as a Qt resource (`:/fragment.glsl`, with `:/vertex.glsl`). It is stored uncompressed in `.rdata` (file offset `0xddfb44`, 5378 bytes). Extracted copies are in [`extracted/`](../extracted/).

* It is **"Protean clouds" by nimitz** (<https://www.shadertoy.com/view/3l23Rh>), licensed **CC BY-NC-SA 3.0**. The About box credits it ("Based on cloud shader").
* Changes from the Shadertoy original:
  * Shadertoy inputs were replaced with uniforms `iTime`, `iWidth` and `iHeight`, plus a global `vec2 iResolution = vec2(iWidth, iHeight)`.
  * `gl_FragColor` and `gl_FragCoord` are used instead of `mainImage`.
  * The mouse term `bsMo` is fixed at `-0.5 * iResolution.xy / iResolution.y`. This permanently offsets the camera sideways by an amount that depends on the aspect ratio, so ultrawide and portrait screens see a different framing. The remake keeps this as-is.
* The vertex shader is `gl_Position = ftransform();`. That is legacy fixed-function GLSL, so the app needs an OpenGL compatibility profile.
* Cost per pixel: up to 130 ray-march steps, and each step calls `map()` 1–3 times (5 noise octaves each). That means **hundreds of trig-heavy noise evaluations per pixel, every frame**. At 3440×1440 that is about 5 million pixels per frame.

## Host program

* Qt `QOpenGLWidget`. The uniform names `iTime`, `iWidth` and `iHeight` sit next to the resource paths in `.rdata`.
* About dialog: build date, "using %1 threads" (`QThread::idealThreadCount`), the GPU it is "Running on", a "Recommended tune" YouTube link, the thesis link, the shader credit and a Virginia Woolf quote: *"There was a star riding through clouds one night, and I said to the star, 'Consume me'."*
* It writes a log file, `zzCloud.log`.
* The *Settings* dialog only offers About. There are no quality or speed options.
* Multi-monitor: it imports `EnumDisplayMonitors`, `GetMonitorInfoW` and `MonitorFromWindow`, through Qt's `QScreen` handling. All rendering goes through `opengl32.dll`.

## Why it struggles on a multi-monitor, multi-GPU setup

1. **OpenGL on Windows renders on one GPU.** A window on a monitor attached to another card is rendered on the first card and copied across, and its vsync follows the primary monitor. Mixed refresh rates (175 Hz + 60 Hz) stutter.
2. **Full resolution at full refresh.** On a 175 Hz ultrawide, the ray-marcher runs 175 times a second on about 5 Mpx. This is the most expensive way to show slowly drifting clouds.
3. There is no render-scale, frame-cap or quality setting to trade any of this off.
4. Qt adds 16 MB and a widget stack to what is essentially one draw call.

## How the remake fixes it

`tools/ssbuild.py` + `common/shaderkit.h` (see the README):

| | zzCloud.scr | Remake |
|---|---|---|
| API | OpenGL (Qt), one GPU | Direct3D 11, **one device per monitor on the GPU that drives it** |
| Pacing | primary monitor's vsync | flip-model swap chain + waitable object **per monitor** |
| Shader rate | every refresh | **frame-rate cap** (30–120 fps or refresh); other refreshes re-show the last image |
| Resolution | native | **Auto** (GPU-timed, steers the pass to ~50% of the frame budget) or 100/75/50/35% + bilinear upscale into a 10-bit target |
| Multi-monitor | Qt windows | **Span** one continuous image across all monitors, **Same** view, or **Different** view per monitor |
| MSAA | n/a | forced off (pointless for a full-screen pass) |
| Extras | none | OLED care (rest-to-black, pixel orbit, burn-in guard), Themes & Effects, speed slider |
| Size | 17.1 MB | ~0.37 MB |
