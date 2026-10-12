// Kaleido Bloom - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float t = iTime * 0.2;
    float n = floor(mix(4.0, 14.0, mirrors));
    float a = atan(uv.y, uv.x) + t, r = length(uv);
    float seg = 6.28318 / n;
    a = abs(mod(a, seg) - seg * 0.5);
    vec2 p = vec2(cos(a), sin(a)) * r;
    vec3 col = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        p = abs(p * 1.6) - vec2(0.4 + 0.1 * sin(t * 2.0), 0.3);
        p = rot(t + float(i)) * p;
        col += pal(length(p) + t + float(i) * 0.2, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.1, 0.2)) * 0.02 / abs(p.y + 0.02 * sin(p.x * 8.0));
    }
    col = 1.0 - exp(-col * 0.6);
    gl_FragColor = vec4(col * smoothstep(1.2, 0.2, r), 1.0);
}
