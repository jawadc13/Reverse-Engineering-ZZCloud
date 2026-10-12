// Ring Tunnel - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float t = iTime;
    uv += vec2(sin(t * 0.5), cos(t * 0.37)) * 0.1 * twist;
    float r = length(uv), a = atan(uv.y, uv.x);
    float z = 0.3 / max(r, 0.001) + t * 1.5;
    float ang = a / 6.28318 + z * 0.05 * twist + t * 0.05;
    float rings = pow(abs(sin(z * 3.14159)), 30.0);
    float segs = smoothstep(0.4, 0.5, abs(fract(ang * 12.0) - 0.5));
    vec3 c = pal(z * 0.05, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.1, 0.4, 0.7));
    vec3 col = c * (rings * 1.5 + segs * 0.25) + c * 0.05;
    col *= smoothstep(0.0, 0.25, r);
    gl_FragColor = vec4(col, 1.0);
}
