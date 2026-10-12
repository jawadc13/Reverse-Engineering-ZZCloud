// Warp Stars - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec3 col = vec3(0.0);
    float t = iTime * 0.25;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float z = fract(fi / 6.0 - t);
        float fade = smoothstep(0.0, 0.3, z) * smoothstep(1.0, 0.85, z);
        vec2 p = uv * mix(20.0, 0.5, z) + fi * 31.7;
        vec2 cell = floor(p * 4.0);
        vec2 f = fract(p * 4.0) - 0.5;
        float h = hash(cell + fi);
        if (h < mix(0.05, 0.35, density)) {
            vec2 o = (hash2(cell) - 0.5) * 0.6;
            vec2 dir = normalize(uv + 1e-4);
            vec2 d = f - o;
            float along = dot(d, dir), across = dot(d, vec2(-dir.y, dir.x));
            float streak = exp(-across * across * 900.0) * exp(-along * along * mix(900.0, 40.0, z));
            col += mix(vec3(0.6, 0.7, 1.0), vec3(1.0, 0.9, 0.8), h * 3.0) * streak * fade * 1.5;
        }
    }
    gl_FragColor = vec4(col, 1.0);
}
