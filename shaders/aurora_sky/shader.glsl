// Aurora Sky - original example shader for the builder (public domain / CC0).
// Curtains of aurora over a starry sky and a dark horizon.
// Uses the saver's sliders by name: `intensity` and `stars` (0..1).

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
    return v;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.y;          // desktop-wide in Span mode
    float aspect = iResolution.x / iResolution.y;
    float t = iTime * 0.15;
    vec3 col = mix(vec3(0.005, 0.01, 0.03), vec3(0.02, 0.04, 0.09), uv.y);

    // Stars: one per cell, twinkling.
    vec2 cell = floor(fragCoord / 6.0);
    float h = hash(cell);
    float density = mix(0.002, 0.02, stars);
    if (h < density) {
        vec2 c = (cell + 0.5) * 6.0;
        float d = length(fragCoord - c);
        col += vec3(0.8, 0.85, 1.0) * smoothstep(1.6, 0.0, d) * (0.6 + 0.4 * sin(iTime * 3.0 + h * 600.0));
    }

    // Aurora: several bands, each a wavy curtain with vertical rays.
    vec3 aur = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float x = uv.x * (0.6 + 0.15 * fi) + fi * 3.1;
        float base = 0.55 + 0.12 * fi + 0.08 * sin(x * 1.3 + t * (1.0 + 0.3 * fi)) + 0.1 * (fbm(vec2(x * 0.8, t * 0.5 + fi)) - 0.5);
        float dy = uv.y - base;
        float curtain = exp(-max(dy, 0.0) * 6.0) * smoothstep(-0.04, 0.0, dy);
        float rays = 0.5 + 0.5 * fbm(vec2(x * 18.0, t * 2.0 + fi * 7.0));
        vec3 tint = mix(vec3(0.1, 1.0, 0.45), vec3(0.6, 0.25, 1.0), clamp(dy * 3.0 + 0.2 * fi, 0.0, 1.0));
        aur += tint * curtain * rays * (0.35 - 0.05 * fi);
    }
    col += aur * mix(0.4, 1.6, intensity);

    // Hills on the horizon.
    float hill = 0.12 + 0.05 * fbm(vec2(uv.x * 2.0, 3.0)) + 0.03 * sin(uv.x * 3.0);
    col = mix(col, vec3(0.003, 0.006, 0.01), smoothstep(hill + 0.003, hill - 0.003, uv.y));

    fragColor = vec4(pow(col, vec3(0.9)), 1.0);
}
