// Bokeh City - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float t = iTime * 0.1;
    vec3 col = mix(vec3(0.02, 0.02, 0.06), vec3(0.08, 0.04, 0.1), uv.y);
    for (int l = 0; l < 4; l++) {
        float fl = float(l), sc = 3.0 + fl * 2.0;
        vec2 p = uv * sc + vec2(t * (1.0 + fl * 0.5), fl * 7.3);
        vec2 c = floor(p), f = fract(p);
        for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
            vec2 cc = c + vec2(float(x), float(y));
            if (hash(cc + fl) > 0.55) continue;
            vec2 o = hash2(cc + fl * 3.0);
            float r = mix(0.15, 0.45, hash(cc + 9.1)) * mix(0.6, 1.3, blur);
            float d = length(f - vec2(float(x), float(y)) - o);
            float disk = smoothstep(r, r * mix(0.9, 0.4, blur), d) * (0.7 + 0.3 * smoothstep(r * 0.6, r, d));
            vec3 lc = pal(hash(cc * 1.7), vec3(0.6, 0.45, 0.3), vec3(0.4, 0.3, 0.3), vec3(1.0), vec3(0.0, 0.1, 0.2));
            col += lc * disk * 0.35 * (0.6 + 0.4 * sin(iTime + hash(cc) * 20.0));
        }
    }
    gl_FragColor = vec4(col, 1.0);
}
