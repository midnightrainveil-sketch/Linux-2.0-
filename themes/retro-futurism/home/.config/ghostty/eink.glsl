// e-ink, for Ghostty (custom-shader): the screen as the theme's e-ink
// devices have it. The glass a touch lighter at the top left, darker
// toward its foot; the rim's shadow along its top edge; a fixed paper
// grain; and the ink spreading a hair into the glass, as e-ink does.
// Nothing moves (custom-shader-animation = false): it costs a pass only
// when the text changes.

float grain(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 px = 1.0 / iResolution.xy;
    vec4 c = texture(iChannel0, uv);

    // the ink spreads: a little of the darkest neighbour (neighbours kept
    // inside the screen: past its edge the texture reads black, which drew
    // a dark line along the edges)
    vec2 lo = 0.5 * px, hi = 1.0 - 0.5 * px;
    vec3 n = min(min(texture(iChannel0, clamp(uv + vec2(px.x, 0.0), lo, hi)).rgb,
                     texture(iChannel0, clamp(uv - vec2(px.x, 0.0), lo, hi)).rgb),
                 min(texture(iChannel0, clamp(uv + vec2(0.0, px.y), lo, hi)).rgb,
                     texture(iChannel0, clamp(uv - vec2(0.0, px.y), lo, hi)).rgb));
    vec3 col = mix(c.rgb, min(c.rgb, n), 0.32);

    // the glass: lighter at the top left, darker toward the foot and right
    // (uv.y is 1 at the top)
    float shade = 1.0 + 0.030 * (uv.y - 0.5) - 0.015 * (uv.x - 0.5);
    // the rim's shadow along the top: faint and soft (stronger, at the desk
    // terminal's small size it read as a dark bar)
    float fromTop = iResolution.y - fragCoord.y;
    shade *= 1.0 - 0.035 * exp(-fromTop / 24.0);
    // the grain: on the glass more than on the ink
    float paper = dot(col, vec3(0.333));
    float g = (grain(floor(fragCoord)) - 0.5) * 0.035 * paper;

    fragColor = vec4(clamp(col * shade + g, 0.0, 1.0), c.a);
}
