// Electric Storm - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec3 col = vec3(0.03, 0.02, 0.08) + vec3(0.08, 0.06, 0.15) * fbm(uv * 2.0 + vec2(t * 0.05, 0.0));
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float seed = floor(t * mix(0.5, 2.0, energy) + fi * 0.37);
        float y0 = (hash(vec2(seed, fi)) - 0.5) * 0.8;
        float y = y0 + (fbm(vec2(uv.x * 3.0 + seed * 13.0, fi)) - 0.5) * 0.6 + (noise(vec2(uv.x * 25.0, seed)) - 0.5) * 0.05;
        float d = abs(uv.y - y);
        float flash = pow(1.0 - fract(t * mix(0.5, 2.0, energy) + fi * 0.37), 3.0);
        col += vec3(0.6, 0.7, 1.0) * (0.0015 / (d + 0.001) + 0.05 * exp(-d * 10.0)) * flash;
    }
    gl_FragColor = vec4(1.0 - exp(-col * 1.5), 1.0);
}
