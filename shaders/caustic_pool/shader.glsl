// Caustic Pool - original shader for the builder (CC0). Plain main() style, like zzCloud.
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

// Caustics: bright where two warped Voronoi-edge layers meet.
float cells(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    float d1 = 9.0, d2 = 9.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        vec2 g = vec2(float(x), float(y));
        vec2 o = 0.5 + 0.4 * sin(iTime * 0.8 + 6.28318 * hash2(i + g));
        float d = length(g + o - f);
        if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
    }
    return d2 - d1;   // 0 on cell edges
}

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.y * mix(3.0, 7.0, depth);
    vec2 w = uv + 0.3 * vec2(fbm(uv * 0.7 + iTime * 0.1), fbm(uv * 0.7 - iTime * 0.1));
    float c = exp(-cells(w) * 14.0) + exp(-cells(w * 1.3 + 7.0) * 18.0) * 0.6;
    vec2 tile = abs(fract(uv * 0.5) - 0.5);
    vec3 col = vec3(0.0, 0.32, 0.45) * (0.85 + 0.15 * smoothstep(0.46, 0.49, max(tile.x, tile.y)));
    col += vec3(0.75, 0.95, 1.0) * pow(c, 1.5) * 0.8;
    gl_FragColor = vec4(col, 1.0);
}
