// Ink Marble - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = gl_FragCoord.xy / iResolution.y * 2.0;
    float t = iTime * 0.08;
    vec2 p = uv;
    for (int i = 0; i < 4; i++) p += mix(0.4, 1.2, swirl) * vec2(fbm(p + t + float(i)), fbm(p - t + 3.1 * float(i))) - 0.4;
    float f = fbm(p * 1.5);
    vec3 col = mix(vec3(0.95, 0.9, 0.8), vec3(0.05, 0.25, 0.5), smoothstep(0.3, 0.7, f));
    col = mix(col, vec3(0.7, 0.2, 0.15), smoothstep(0.55, 0.75, fbm(p * 2.0 + 4.0)) * 0.8);
    col *= 0.85 + 0.15 * sin(f * 40.0);
    gl_FragColor = vec4(col, 1.0);
}
