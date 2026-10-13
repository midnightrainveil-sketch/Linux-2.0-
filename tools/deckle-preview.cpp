// Render the window edge (the deckle) outside Hyprland, to look at it.
//
//   g++ -std=c++20 -O2 -I dotfiles/.local/share/archive/plugins/archivebars
//       tools/deckle-preview.cpp dotfiles/.local/share/archive/plugins/archivebars/deckle.cpp
//       $(pkg-config --cflags --libs cairo) -o /tmp/deckle-preview
//   /tmp/deckle-preview out.png [width height scale day|night [bare] [seed]]
//
// Draws one card the size of a window on the desk colour, using exactly the
// tiles the plugin uses: the tiles under the window, a plain window with the
// title bar's dots and rule, then the tiles over it. "bare" instead writes
// out-under.png and out-over.png on transparency, to lay under and over a
// mock-up of the window.
#include "deckle.hpp"

#include <cstdio>
#include <cstdlib>
#include <string>

int main(int argc, char** argv) {
    const std::string out   = argc > 1 ? argv[1] : "deckle.png";
    const double      w     = argc > 2 ? atof(argv[2]) : 686;
    const double      h     = argc > 3 ? atof(argv[3]) : 518;
    const double      scale = argc > 4 ? atof(argv[4]) : 1.0;
    const bool        night = argc > 5 && std::string(argv[5]) == "night";
    const bool        bare  = argc > 6 && std::string(argv[6]) == "bare";
    const uint32_t    seed  = argc > 7 ? (uint32_t)strtoul(argv[7], nullptr, 0) : 0x5eed;
    const double      M     = 48; // desk around the card

    Deckle::SStyle    st;
    st.scale = scale;
    if (night) {
        st.paper     = 0xff22385a;
        st.rimTop    = 0xff4e6283;
        st.rimBottom = 0xff0b1424;
        st.bevel     = 0x269fb4d6;
        st.shadow    = 0x8c08101e;
        st.tone      = 0x40050b16;
    }
    const uint32_t desk = night ? 0x1c2f4d : 0xc9c7c3;
    const uint32_t card = st.paper;
    const int      W = (int)((w + 2 * M) * scale), H = (int)((h + 2 * M) * scale);
    const double   m = st.margin; // the card edge is `margin` outside the window

    auto           surface = [&] { return cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H); };
    auto           rgb     = [](cairo_t* cr, uint32_t c, double a = 1) { cairo_set_source_rgba(cr, ((c >> 16) & 255) / 255.0, ((c >> 8) & 255) / 255.0, (c & 255) / 255.0, a); };

    if (bare) {
        cairo_surface_t* under = surface();
        cairo_t*         cr    = cairo_create(under);
        Deckle::composeCard(cr, st, M - m, M - m, w + 2 * m, h + 2 * m, seed);
        cairo_destroy(cr);
        cairo_surface_t* over = surface();
        cr                    = cairo_create(over);
        Deckle::composeOverlay(cr, st, M - m, M - m, w + 2 * m, h + 2 * m, seed);
        cairo_destroy(cr);
        const std::string stem = out.substr(0, out.rfind('.'));
        cairo_surface_write_to_png(under, (stem + "-under.png").c_str());
        cairo_surface_write_to_png(over, (stem + "-over.png").c_str());
        cairo_surface_destroy(under);
        cairo_surface_destroy(over);
        printf("%s-under.png, %s-over.png: %dx%d\n", stem.c_str(), stem.c_str(), W, H);
        return 0;
    }

    cairo_surface_t* s  = surface();
    cairo_t*         cr = cairo_create(s);
    rgb(cr, desk);
    cairo_paint(cr);

    Deckle::composeCard(cr, st, M - m, M - m, w + 2 * m, h + 2 * m, seed);

    // the window: plain paper, title bar dots and rule, as archivebars draws them
    cairo_save(cr);
    cairo_scale(cr, scale, scale);
    rgb(cr, card);
    cairo_rectangle(cr, M, M, w, h);
    cairo_fill(cr);
    const double dot = night ? 0.56 : 0.37;
    for (int i = 0; i < 3; ++i) {
        cairo_arc(cr, M + 20 + 5.5 + i * 21, M + 23, 5.5, 0, 6.2832);
        cairo_set_source_rgb(cr, dot, dot, dot * 1.04);
        cairo_fill(cr);
    }
    cairo_rectangle(cr, M + 11, M + 45, w - 22, 1);
    cairo_set_source_rgba(cr, night ? 0.72 : 0.29, night ? 0.75 : 0.286, night ? 0.8 : 0.314, 0.67);
    cairo_fill(cr);
    cairo_restore(cr);

    Deckle::composeOverlay(cr, st, M - m, M - m, w + 2 * m, h + 2 * m, seed);

    cairo_destroy(cr);
    cairo_surface_write_to_png(s, out.c_str());
    cairo_surface_destroy(s);
    printf("%s: %dx%d (outset %d, corner %d)\n", out.c_str(), W, H, st.outset(), st.cornerSize());
    return 0;
}
