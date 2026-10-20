// The desk cards' torn edge: the windows' edge (the deckle), drawn into
// frame images for the shell's cards (components/Paper.qml lays them out as
// a BorderImage, so any card size gets the same edge as a window).
//
//   g++ -std=c++20 -O2 -I dotfiles/.local/share/archive/plugins/archivebars
//       tools/card-frames.cpp dotfiles/.local/share/archive/plugins/archivebars/deckle.cpp
//       $(pkg-config --cflags --libs cairo) -o /tmp/card-frames
//   /tmp/card-frames dotfiles/.config/quickshell/assets/card
//
// Writes {day,night}-{under,over}.png and their @2x: a card (2 corners and
// 3 strips across, 1 strip down, so nothing is stretched) with room for the
// shadow around it. under: the shadow, the paper, the torn outline, chips and
// worn corners; over: the aged edge and small tears, which lie over the
// card's own content near its edge. The colours are the windows' (palette.lua).
#include "deckle.hpp"

#include <cmath>
#include <cstdio>
#include <string>

static void frames(const std::string& dir, const char* mode, Deckle::SStyle st) {
    st.creases = 0; // a crease reaches past the corner, and would be stretched
    const double O = st.outset(), R = st.cornerReach();
    const double w = 2 * R + 3 * st.period, h = 2 * R + st.period;
    for (int scale : {1, 2}) {
        st.scale       = scale;
        const int W    = (int)std::lround((w + 2 * O) * scale), H = (int)std::lround((h + 2 * O) * scale);
        const auto out = [&](const char* layer) { return dir + "/" + mode + "-" + layer + (scale == 2 ? "@2x" : "") + ".png"; };

        cairo_surface_t* under = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H);
        cairo_t*         cr    = cairo_create(under);
        Deckle::composeCard(cr, st, O, O, w, h, 0x5eed);
        cairo_destroy(cr);
        cairo_surface_write_to_png(under, out("under").c_str());
        cairo_surface_destroy(under);

        cairo_surface_t* over = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H);
        cr                    = cairo_create(over);
        Deckle::composeOverlay(cr, st, O, O, w, h, 0x5eed);
        cairo_destroy(cr);
        cairo_surface_write_to_png(over, out("over").c_str());
        cairo_surface_destroy(over);
    }
    std::printf("%s: card %.0f x %.0f, shadow room %.0f, corner %.0f (border %.0f)\n", mode, w, h, O, R, O + R);
}

int main(int argc, char** argv) {
    const std::string dir = argc > 1 ? argv[1] : ".";
    Deckle::SStyle    day; // look.lua's extras, day palette
    day.paper     = 0xffd5d0ca;
    day.rimTop    = 0xffa09b94;
    day.rimBottom = 0xff57524d;
    day.bevel     = 0x59ffffff;
    day.shadow    = 0x661e1d22;
    day.tone      = 0x30604c38;
    frames(dir, "day", day);

    Deckle::SStyle night = day;
    night.paper     = 0xff22385a;
    night.rimTop    = 0xff4e6283;
    night.rimBottom = 0xff0b1424;
    night.bevel     = 0x269fb4d6;
    night.shadow    = 0x8c08101e;
    night.tone      = 0x40050b16;
    frames(dir, "night", night);
}
