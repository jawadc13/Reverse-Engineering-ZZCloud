// Silk Ribbons - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float t = iTime * 0.5;
    vec3 col = vec3(0.0);
    int n = int(mix(3.0, 10.0, ribbons));
    for (int i = 0; i < 10; i++) {
        if (i >= n) break;
        float fi = float(i);
        float y = 0.25 * sin(uv.x * (1.5 + 0.3 * fi) + t * (1.0 + 0.1 * fi) + fi) + 0.1 * sin(uv.x * 4.0 - t + fi * 2.0);
        y += (fi - float(n) * 0.5) * 0.04;
        float w = 0.004 + 0.02 * (0.5 + 0.5 * sin(uv.x * 3.0 + t * 1.3 + fi));
        float d = abs(uv.y - y);
        vec3 c = pal(fi / float(n) + t * 0.05, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.8, 0.9, 0.3));
        col += c * (smoothstep(w, 0.0, d) * 0.6 + w * 0.02 / (d + 0.01));
    }
    gl_FragColor = vec4(1.0 - exp(-col), 1.0);
}
