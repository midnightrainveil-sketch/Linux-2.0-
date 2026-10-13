// Render the window edge (the deckle) outside Hyprland, to look at it.
//
//   g++ -std=c++20 -O2 -I dotfiles/.local/share/archive/plugins/archivebars
//       tools/deckle-preview.cpp dotfiles/.local/share/archive/plugins/archivebars/deckle.cpp
//       $(pkg-config --cflags --libs cairo) -o /tmp/deckle-preview
//   /tmp/deckle-preview out.png [width height scale day|night [bare]]
//
// Draws one card the size of a window, with the title bar's dots and rule, on
// the desk colour, using exactly the tiles the plugin uses. "bare" leaves out
// the desk and the title bar (a transparent card to lay under a mock-up).
#include "deckle.hpp"

#include <cstdio>
#include <cstdlib>
#include <string>

int main(int argc, char** argv) {
    const char*   out   = argc > 1 ? argv[1] : "deckle.png";
    const double  w     = argc > 2 ? atof(argv[2]) : 686;
    const double  h     = argc > 3 ? atof(argv[3]) : 518;
    const double  scale = argc > 4 ? atof(argv[4]) : 1.0;
    const bool    night = argc > 5 && std::string(argv[5]) == "night";
    const bool    bare  = argc > 6 && std::string(argv[6]) == "bare";
    const double  M = 48; // desk around the card

    Deckle::SStyle st;
    st.scale = scale;
    if (night) {
        st.paper     = 0xff22385a;
        st.rimTop    = 0xff4e6283;
        st.rimBottom = 0xff0b1424;
        st.bevel     = 0x269fb4d6;
        st.shadow    = 0x8c08101e;
    }
    const uint32_t desk = night ? 0x1c2f4d : 0xc9c7c3;

    const int        W = (int)((w + 2 * M) * scale), H = (int)((h + 2 * M) * scale);
    cairo_surface_t* s  = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H);
    cairo_t*         cr = cairo_create(s);
    cairo_set_source_rgb(cr, ((desk >> 16) & 255) / 255.0, ((desk >> 8) & 255) / 255.0, (desk & 255) / 255.0);
    if (!bare)
        cairo_paint(cr);

    // the card edge is `margin` outside the window
    const double m = st.margin;
    Deckle::composeCard(cr, st, M - m, M - m, w + 2 * m, h + 2 * m, 0x5eed);

    // title bar: three dots and the rule, as archivebars draws them
    cairo_scale(cr, scale, scale);
    if (bare)
        cairo_set_operator(cr, CAIRO_OPERATOR_DEST); // draw nothing more
    const double dot = night ? 0.56 : 0.37;
    for (int i = 0; i < 3; ++i) {
        cairo_arc(cr, M + 20 + 5.5 + i * 21, M + 23, 5.5, 0, 6.2832);
        cairo_set_source_rgb(cr, dot, dot, dot * 1.04);
        cairo_fill(cr);
    }
    cairo_rectangle(cr, M + 11, M + 45, w - 22, 1);
    cairo_set_source_rgba(cr, night ? 0.72 : 0.29, night ? 0.75 : 0.286, night ? 0.8 : 0.314, 0.67);
    cairo_fill(cr);

    cairo_destroy(cr);
    cairo_surface_write_to_png(s, out);
    cairo_surface_destroy(s);
    printf("%s: %dx%d (outset %d, corner %d)\n", out, W, H, st.outset(), st.cornerSize());
    return 0;
}
