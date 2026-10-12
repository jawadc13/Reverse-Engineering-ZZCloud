// Rain Ripples - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = gl_FragCoord.xy / iResolution.y * mix(3.0, 8.0, rain);
    float t = iTime;
    float h = 0.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec2 c = floor(uv) + vec2(float(x), float(y));
        vec2 o = hash2(c);
        float ph = fract(t * 0.4 + hash(c + 3.3));
        float d = length(uv - c - o);
        float r = ph * 1.2;
        h += sin((d - r) * 30.0) * smoothstep(0.15, 0.0, abs(d - r)) * (1.0 - ph) * (1.0 - ph);
    }
    vec3 col = vec3(0.01, 0.02, 0.05) + vec3(0.3, 0.5, 0.8) * max(h, 0.0) * 0.6
             + vec3(0.6, 0.6, 0.9) * pow(max(h, 0.0), 4.0);
    col += vec3(0.02, 0.03, 0.06) * fbm(uv * 0.3 + t * 0.02);
    gl_FragColor = vec4(col, 1.0);
}
