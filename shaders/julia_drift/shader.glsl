// Julia Drift - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y * 2.6;
    float t = iTime * 0.1;
    vec2 c = vec2(-0.75 + 0.2 * cos(t), 0.15 + 0.25 * sin(t * 1.3));
    vec2 z = rot(t * 0.5) * uv;
    float m = 0.0; int it = int(mix(48.0, 160.0, detail)); float k = 0.0;
    for (int i = 0; i < 160; i++) {
        if (i >= it) break;
        z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (dot(z, z) > 64.0) break;
        k += 1.0;
    }
    float sm = k - log2(log2(max(dot(z, z), 1.0001))) + 4.0;
    vec3 col = k >= float(it) ? vec3(0.0) : pal(sm * 0.02 + t, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.15, 0.3)) * clamp(sm * 0.08, 0.0, 1.0);
    gl_FragColor = vec4(col, 1.0);
}
