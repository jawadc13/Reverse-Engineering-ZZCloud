// Golden Dunes - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    float aspect = iResolution.x / iResolution.y;
    float t = iTime * 0.03;
    vec3 col = mix(vec3(1.0, 0.75, 0.45), vec3(0.45, 0.6, 0.9), uv.y);
    col += vec3(1.0, 0.8, 0.5) * 0.15 / (length((uv - vec2(0.7, 0.75)) * vec2(aspect, 1.0)) + 0.1);
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float x = uv.x * aspect * (1.0 + fi * 0.5) + t * (1.0 + fi) * (0.3 + wind) + fi * 13.0;
        float h = 0.55 - fi * 0.11 + 0.08 * fbm(vec2(x * 0.8, fi)) + 0.04 * sin(x * 2.0);
        if (uv.y < h) {
            float shade = 0.5 + 0.5 * sin(x * 2.0 + 1.0);
            vec3 sand = mix(vec3(0.75, 0.45, 0.2), vec3(1.0, 0.75, 0.45), shade) * (0.55 + fi * 0.12);
            sand *= 0.95 + 0.05 * sin((uv.y * 300.0 + x * 40.0) * (0.5 + wind));
            col = mix(sand, col, exp(-fi * 0.0) * 0.25 * (4.0 - fi) / 4.0);
        }
    }
    gl_FragColor = vec4(col, 1.0);
}
