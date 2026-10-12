// Spiral Galaxy - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    vec2 uv = (gl_FragCoord.xy - 0.5 * iResolution.xy) / iResolution.y * 1.6;
    float t = iTime * 0.05;
    uv = rot(0.4) * uv; uv.y *= 1.6;
    float r = length(uv), a = atan(uv.y, uv.x);
    float spiral = sin(2.0 * a + log(r + 0.01) * mix(3.0, 7.0, arms) - t * 4.0);
    float dust = fbm(vec2(a * 3.0 + t, r * 6.0 - t));
    float arm = smoothstep(0.0, 1.0, spiral * 0.5 + 0.5) * exp(-r * 2.2);
    vec3 col = vec3(0.5, 0.6, 1.0) * arm * (0.4 + dust) + vec3(1.0, 0.8, 0.5) * exp(-r * 9.0) * 1.2;
    col *= 1.0 - 0.6 * smoothstep(0.5, 0.8, dust) * arm;
    float s = hash(floor(gl_FragCoord.xy / 3.0));
    col += step(0.995, s) * vec3(0.8) * (0.5 + 0.5 * sin(iTime * 2.0 + s * 100.0));
    gl_FragColor = vec4(col, 1.0);
}
