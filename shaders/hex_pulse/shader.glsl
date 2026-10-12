// Hex Pulse - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y * mix(5.0, 18.0, size);
    vec2 s = vec2(1.0, 1.7320508);
    vec2 a = mod(uv, s) - s * 0.5, b = mod(uv - s * 0.5, s) - s * 0.5;
    vec2 h = dot(a, a) < dot(b, b) ? a : b;
    vec2 id = uv - h;
    float edge = max(abs(h.x), dot(abs(h), normalize(s)));
    float t = iTime;
    float wave = sin(length(id) * 0.6 - t * 2.0 + sin(id.x * 0.3 + t * 0.5) * 2.0) * 0.5 + 0.5;
    vec3 c = pal(length(id) * 0.03 - t * 0.05, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.3, 0.5, 0.6));
    vec3 col = c * pow(wave, 3.0) * smoothstep(0.5, 0.42, edge) + c * 0.3 * smoothstep(0.44, 0.5, edge) * smoothstep(0.52, 0.5, edge);
    gl_FragColor = vec4(col, 1.0);
}
