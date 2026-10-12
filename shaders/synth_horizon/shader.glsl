// Synth Horizon - original shader for the builder (CC0). Plain main() style, like zzCloud.
uniform float iTime;
uniform vec3 iResolution;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 17.31)); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = mat2(1.6, 1.2, -1.2, 1.6) * p; a *= 0.5; }
    return v;
}
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, s, -s, c); }
vec3 pal(float t, vec3 a, vec3 b, vec3 c, vec3 d) { return a + b * cos(6.28318 * (c * t + d)); }

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime;
    vec3 col = mix(vec3(0.15, 0.0, 0.25), vec3(0.0), clamp(uv.y * 2.0, 0.0, 1.0));
    vec2 sp = uv - vec2(0.0, 0.12);
    float sun = smoothstep(0.26, 0.25, length(sp));
    float stripes = step(0.0, sin(sp.y * 80.0 - t * 2.0)) + step(0.05, sp.y);
    col += mix(vec3(1.0, 0.2, 0.5), vec3(1.0, 0.85, 0.2), clamp(sp.y * 3.0 + 0.6, 0.0, 1.0)) * sun * min(stripes, 1.0);
    if (uv.y < 0.0) {
        float z = 0.25 / -uv.y;
        vec2 g = vec2(uv.x * z, z + t * 2.0);
        vec2 gd = abs(fract(g) - 0.5) / fwidth(g);
        float line = 1.0 - min(min(gd.x, gd.y), 1.0);
        col = vec3(0.02, 0.0, 0.05) + vec3(1.0, 0.1, 0.8) * line * mix(0.6, 1.6, glow) * exp(-z * 0.05);
        col += vec3(0.6, 0.0, 0.5) * exp(uv.y * 30.0) * 0.5;
    }
    gl_FragColor = vec4(col, 1.0);
}
