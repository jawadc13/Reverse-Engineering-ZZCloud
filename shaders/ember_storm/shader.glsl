// Ember Storm - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = gl_FragCoord.xy / iResolution.y;
    float t = iTime;
    vec3 col = vec3(0.3, 0.05, 0.0) * pow(1.0 - clamp(uv.y, 0.0, 1.0), 3.0) * (0.6 + 0.4 * fbm(vec2(uv.x * 4.0, t)));
    for (int i = 0; i < 4; i++) {
        float fi = float(i), sc = 6.0 + fi * 5.0;
        vec2 p = uv * sc + vec2(sin(t * 0.3 + fi) * 0.5, -t * (1.0 + fi * 0.3));
        p.x += fbm(p * 0.3 + t * 0.2) * 2.0;
        vec2 c = floor(p), f = fract(p) - 0.5;
        float h = hash(c + fi * 7.0);
        if (h < mix(0.1, 0.45, amount)) {
            vec2 o = (hash2(c) - 0.5) * 0.6;
            float flick = 0.6 + 0.4 * sin(t * 6.0 + h * 50.0);
            col += vec3(1.0, 0.5, 0.1) * smoothstep(0.08, 0.0, length(f - o)) * flick * (1.2 - fi * 0.2);
        }
    }
    gl_FragColor = vec4(col, 1.0);
}
