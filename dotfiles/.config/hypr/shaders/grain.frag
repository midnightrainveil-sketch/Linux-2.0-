// Archive film grain: 2-3 % static paper grain over everything, so even
// third-party apps feel printed. Static on purpose: an animated (time-based)
// grain would force Hyprland to redraw every frame and cost battery.
// Toggle with Super+Shift+G (archive-grain). Shifts colours slightly, so turn
// it off for colour-critical work.

#version 300 es
precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

void main() {
    vec4 color = texture(tex, v_texcoord);
    // two octaves of value noise at roughly screen-pixel scale
    vec2 px = gl_FragCoord.xy;
    float n = hash(floor(px)) * 0.65 + hash(floor(px * 0.5) + 17.0) * 0.35;
    float grain = (n - 0.5) * 0.05;                  // about +-2.5 %
    // grain shows most in the mid-tones, like ink on paper
    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float weight = 0.6 + 0.4 * (1.0 - abs(lum - 0.5) * 2.0);
    color.rgb = clamp(color.rgb + grain * weight, 0.0, 1.0);
    fragColor = color;
}
