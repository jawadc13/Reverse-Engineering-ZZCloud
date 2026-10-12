// Metaballs - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float t = iTime * 0.4;
    float f = 0.0; vec2 g = vec2(0.0);
    int n = int(mix(4.0, 12.0, count));
    for (int i = 0; i < 12; i++) {
        if (i >= n) break;
        float fi = float(i);
        vec2 c = vec2(sin(t * (0.5 + 0.13 * fi) + fi * 2.1) * 0.7, cos(t * (0.4 + 0.11 * fi) + fi * 1.3) * 0.4);
        vec2 d = uv - c;
        float k = 0.012 / dot(d, d);
        f += k; g += -2.0 * k * d / dot(d, d);
    }
    float inside = smoothstep(0.95, 1.05, f);
    vec3 n3 = normalize(vec3(-g * 0.01, 1.0));
    float diff = max(dot(n3, normalize(vec3(-0.5, 0.6, 0.8))), 0.0);
    float spec = pow(max(dot(reflect(vec3(0, 0, -1), n3), normalize(vec3(-0.5, 0.6, 0.8))), 0.0), 40.0);
    vec3 col = mix(vec3(0.0, 0.03, 0.06) + vec3(0.0, 0.2, 0.2) * f * 0.15,
                   vec3(0.0, 0.6, 0.45) * (0.3 + diff) + spec, inside);
    gl_FragColor = vec4(col, 1.0);
}
