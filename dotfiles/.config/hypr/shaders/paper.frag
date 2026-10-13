// Archive paper: makes every window read as printed on card, like the
// reference terminal. Three things, all static (no time uniform, so Hyprland
// only redraws when something on screen changes):
//   * paper   - soft mottling, pale fibres and tooth, strongest on light paper
//               and almost nothing on dark ink, so text stays crisp-dark;
//   * ink     - a sub-pixel nudge of every sample, so straight edges and
//               glyphs pick up the faint raggedness of typewriter ink;
//   * nothing else - no blur, no colour shift beyond about 2 %.
// Toggle with Super+Shift+G (archive-grain). Off for colour-critical work.

#version 300 es
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
    vec2 size = vec2(textureSize(tex, 0));
    vec2 px = v_texcoord * size;

    // ink: nudge the sample by up to ~0.4 px
    vec2 nudge = vec2(vnoise(px * 0.45), vnoise(px * 0.45 + 17.3)) - 0.5;
    vec4 color = texture(tex, (px + nudge * 0.8) / size);

    // paper
    float mottle = vnoise(px / 60.0) * 0.55 + vnoise(px / 18.0) * 0.45;
    float fibre  = vnoise(vec2(px.x / 10.0 + px.y / 33.0, px.y / 2.4 - px.x / 57.0));
    float tooth  = hash(floor(px));
    float speck  = step(0.9993, hash(floor(px / 2.0) + 7.0));
    float grain  = (mottle - 0.5) * 0.070
                 + smoothstep(0.74, 0.97, fibre) * 0.030
                 + (tooth - 0.5) * 0.030
                 - speck * 0.12;

    float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    float onPaper = smoothstep(0.12, 0.70, lum);
    color.rgb = clamp(color.rgb + grain * onPaper, 0.0, 1.0);
    fragColor = color;
}
