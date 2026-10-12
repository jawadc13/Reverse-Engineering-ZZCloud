// shaderkit.h - screensavers made from one full-screen pixel shader (the
// way zzCloud.scr is built, see docs/ZZCLOUD_ANALYSIS.md), on top of the
// shared Direct3D 11 multi-monitor framework.
//
// tools/ssbuild.py turns a Shadertoy-style GLSL shader into HLSL and
// generates a saver that does nothing but construct a ShaderScene. What
// this file adds over a naive "draw the shader every frame at full size":
//
//  * Frame-rate cap. A heavy ray-marcher does not need 175 Hz. The shader
//    runs at most `cap` times a second; in between, the last result is
//    re-shown (a single cheap texture copy), so a 175 Hz monitor costs the
//    same as a 60 Hz one.
//  * Render scale. The shader runs on a smaller target that is stretched to
//    the screen. Fixed (100/75/50/35%) or Auto: the GPU time of the pass is
//    measured with timestamp queries and the scale is steered so the pass
//    takes about half of the frame budget, per monitor, per GPU.
//  * Multi-monitor modes. Span (one continuous image across every monitor,
//    each monitor rendering only its own part), Same on every monitor, or a
//    Different view per monitor. Each monitor still renders on its own
//    thread, on its own GPU, at its own refresh rate (saver.cpp).
//  * MSAA is switched off (it would only cost: the pass is one triangle).
#pragma once
#include "saver.h"
#include "simplecfg.h"
#include <math.h>

#define SHADER_QUALITY_CHOICE  { L"Render &quality:", L"Quality", 0, L"Auto (adaptive)|Ultra (100%)|High (75%)|Balanced (50%)|Performance (35%)" }
#define SHADER_FPS_CHOICE      { L"&Frame-rate cap:", L"FpsCap", 2, L"30 fps|45 fps|60 fps|90 fps|120 fps|Monitor refresh" }
#define SHADER_MONITOR_CHOICE  { L"&Multiple monitors:", L"Monitors", 0, L"Span across all monitors|Same view on every monitor|Different view per monitor" }
#define SHADER_SPEED_SLIDER    { L"Speed", L"Speed", 50, L"Slow", L"Fast" }

namespace shaderkit {

// Must match the uniform block that tools/ssbuild.py wraps every shader in
// (std140: vec3 + float share one 16-byte register).
struct Inputs {
    float resolution[3];   // iResolution (whole span in Span mode), desktop pixels
    float time;            // iTime, seconds
    float mouse[4];        // iMouse (always 0: any mouse movement ends a saver)
    float span[4];         // x, y offset of this monitor (GL bottom-up), 1/scale, target height
    float param[4];        // iParam: the saver's own sliders, 0..1
    float timeDelta;       // iTimeDelta
    float frame;           // iFrame
    float pad[2];
};

// Sets the MSAA cap before WinMain runs (one static instance per saver).
struct NoMultisample { NoMultisample() { g_saverMaxMultisample = 1; } };

inline double Seconds() {
    static LARGE_INTEGER f = {};
    if (!f.QuadPart) QueryPerformanceFrequency(&f);
    LARGE_INTEGER c; QueryPerformanceCounter(&c);
    return (double)c.QuadPart / f.QuadPart;
}

// Layout of the generated settings: choices {quality, fps cap, monitors},
// sliders {speed, up to three of the shader's own parameters}.
class ShaderScene : public Scene {
public:
    ShaderScene(const char* hlsl, size_t len, const SimpleConfig& cfg, float speedMin, float speedMax)
        : hlsl(hlsl), hlslLen(len), cfg(cfg), speedMin(speedMin), speedMax(speedMax) {}

    bool Init(Renderer& r, int w, int h, bool preview) override {
        std::string err;
        if (!r.CreateShaderPass(hlsl, hlslLen, &err)) {
            OutputDebugStringA(err.c_str());
            return false;
        }
        isPreview = preview;
        width = w; height = h;
        DWORD q = cfg.choice[0];
        static const float fixed[] = { 1.0f, 1.0f, 0.75f, 0.5f, 0.35f };
        autoScale = q == 0;
        scale = autoScale ? 0.75f : fixed[q < 5 ? q : 0];
        static const float caps[] = { 30, 45, 60, 90, 120, 0 };
        DWORD c = cfg.choice[1];
        cap = caps[c < 6 ? c : 2];
        mode = cfg.choice[2];
        // "Different view": start each monitor at its own moment of the
        // animation (RandF uses the per-monitor seed). The other modes use
        // the same clock everywhere, so monitors stay in step.
        time = mode == 2 ? RandF(0, 600) : 0;
        if (preview) scale = scale < 0.5f ? scale : 0.5f;   // the preview is tiny; keep Control Panel snappy
        return true;
    }
    void Resize(int w, int h) override { width = w; height = h; dirty = true; }

    void Frame(Renderer& r, float dt) override {
        float speed = speedMin + (speedMax - speedMin) * cfg.slider[0] / 100.0f;
        time += dt * speed;
        double now = Seconds();
        double period = cap > 0 ? 1.0 / cap : 0;
        // Render when the cap allows (a little early is fine: the frame then
        // shows on the next vsync). Otherwise reuse the last image.
        if (dirty || period == 0 || now - lastRender >= period - 0.5 * r.RefreshPeriod()) {
            if (autoScale && !isPreview) Steer(r, period > 0 ? period : r.RefreshPeriod());
            Render(r, now);
        }
        r.DrawShaderResult();
    }

private:
    void Render(Renderer& r, double now) {
        int tw = (int)(width * scale + 0.5f), th = (int)(height * scale + 0.5f);
        if (tw < 16) tw = 16;
        if (th < 16) th = 16;
        Inputs in = {};
        float sx = (float)width / tw, sy = (float)height / th;
        in.resolution[0] = (float)width; in.resolution[1] = (float)height; in.resolution[2] = 1;
        RECT mon, desk;
        if (mode == 0 && !isPreview && SaverMonitorRect(mon, desk)) {
            // Span: shader coordinates are desktop pixels of the whole
            // monitor area; this monitor renders only its own rectangle.
            in.resolution[0] = (float)(desk.right - desk.left);
            in.resolution[1] = (float)(desk.bottom - desk.top);
            in.span[0] = (float)(mon.left - desk.left);
            in.span[1] = (float)(desk.bottom - mon.bottom);
            sx = (float)(mon.right - mon.left) / tw;
            sy = (float)(mon.bottom - mon.top) / th;
        }
        in.span[2] = sx;
        in.span[3] = (float)th;
        in.mouse[0] = in.mouse[1] = 0;
        (void)sy;   // the wrapper uses one factor; targets keep the screen's aspect ratio
        in.time = time;
        in.timeDelta = lastRender > 0 ? (float)(now - lastRender) : 0;
        in.frame = (float)frame++;
        for (int i = 0; i < 3; i++) in.param[i] = cfg.slider[i + 1] / 100.0f;
        r.RunShaderPass(&in, sizeof(in), tw, th);
        lastRender = now;
        dirty = false;
    }

    // Auto quality: keep the pass at ~half the time between rendered frames
    // (the other half is headroom for other monitors on the same GPU, the
    // compositor and the rest of the system). Changes are small, rate
    // limited and quantised, so the image never visibly "pumps".
    void Steer(Renderer& r, double framePeriod) {
        float ms = r.ShaderPassGpuMs();
        double now = Seconds();
        if (ms <= 0 || now - lastSteer < 0.5) return;
        lastSteer = now;
        float budget = (float)(framePeriod * 1000.0 * 0.5);
        float ratio = budget / ms;
        if (ratio > 0.85f && ratio < 1.25f) return;   // close enough: hold
        float next = scale * sqrtf(ratio < 0.25f ? 0.25f : ratio > 2.0f ? 2.0f : ratio);   // cost ~ pixel count
        next = floorf(next * 20 + 0.5f) / 20;                                               // 5% steps
        if (next < 0.25f) next = 0.25f;
        if (next > 1.0f) next = 1.0f;
        if (next != scale) { scale = next; dirty = true; }
    }

    const char* hlsl;
    size_t hlslLen;
    const SimpleConfig& cfg;
    float speedMin, speedMax;
    int width = 0, height = 0;
    bool isPreview = false, autoScale = true, dirty = true;
    float scale = 1, cap = 60, time = 0;
    DWORD mode = 0;
    double lastRender = 0, lastSteer = 0;
    unsigned frame = 0;
};

}  // namespace shaderkit
