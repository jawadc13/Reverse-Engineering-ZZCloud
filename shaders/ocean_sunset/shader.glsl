// Ocean Sunset - original shader for the builder (CC0). Plain main() style, like zzCloud.
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
    float horizon = -0.05;
    vec2 sun = vec2(0.25 * sin(t * 0.02), 0.08 + 0.05 * sin(t * 0.03));
    vec3 sky = mix(vec3(1.0, 0.45, 0.2), vec3(0.15, 0.1, 0.35), clamp((uv.y - horizon) * 2.5, 0.0, 1.0));
    float sd = length(uv - sun);
    sky += vec3(1.0, 0.7, 0.3) * (smoothstep(0.07, 0.065, sd) + 0.04 / (sd + 0.05));
    vec3 col = sky;
    if (uv.y < horizon) {
        float depth = horizon - uv.y;
        vec2 wp = vec2(uv.x / (depth + 0.02), 1.0 / (depth + 0.02));
        float w = fbm(wp * vec2(0.4, 0.15) * (0.5 + waves) + vec2(0.0, t * 0.3));
        vec3 sea = mix(vec3(0.05, 0.05, 0.15), vec3(0.3, 0.15, 0.2), w);
        float glint = exp(-abs(uv.x - sun.x) * (10.0 + 20.0 * w) / (depth * 4.0 + 0.2)) * smoothstep(0.4, 0.8, w);
        col = sea + vec3(1.0, 0.6, 0.3) * glint;
        col = mix(col, sky * 0.6, exp(-depth * 30.0));
    }
    gl_FragColor = vec4(col, 1.0);
}
