// A look at the rim without Hyprland: lays the pieces round a window just as
// the plugin does (stretched with linear filtering, as the GPU does), then
// the window over them, rounded, and saves a PNG.
//
//   g++ -std=c++2b preview.cpp $(pkg-config --cflags --libs cairo) -o rim-preview
//   ./rim-preview out.png [scale] [background.png]
#include "RimPaint.hpp"

#include <cstdio>
#include <cstdlib>
#include <string>

using namespace RimPaint;

static void put(cairo_t* cr, cairo_surface_t* piece, int x, int y, int w, int h) {
    if (w <= 0 || h <= 0)
        return;
    const double pw = cairo_image_surface_get_width(piece), ph = cairo_image_surface_get_height(piece);
    cairo_save(cr);
    cairo_rectangle(cr, x, y, w, h);
    cairo_clip(cr);
    cairo_translate(cr, x, y);
    cairo_scale(cr, w / pw, h / ph);
    cairo_set_source_surface(cr, piece, 0, 0);
    cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_BILINEAR);
    cairo_pattern_set_extend(cairo_get_source(cr), CAIRO_EXTEND_PAD);
    cairo_paint(cr);
    cairo_restore(cr);
}

static void window(cairo_t* cr, const SLook& lk, double x, double y, double w, double h) {
    const double s = lk.scale;
    // the rim's outer edge: the window's, out by the rim less its overlap
    const double out = lk.width - lk.overlap;
    const int    x0 = std::lround((x - out) * s), y0 = std::lround((y - out) * s);
    const int    x1 = std::lround((x + w + out) * s), y1 = std::lround((y + h + out) * s);
    const int    C = cornerSize(lk), F = 2 * C + 4;
    const int    W = x1 - x0, H = y1 - y0, cw = std::min(C, W / 2), ch = std::min(C, H / 2);

    cairo_surface_t* pieces[8] = {paint(lk, F, false, 0, 0, C, C),     paint(lk, F, false, F - C, 0, C, C), paint(lk, F, true, 0, F - C, C, C),
                                  paint(lk, F, true, F - C, F - C, C, C), paint(lk, F, false, C + 1, 0, 1, C),  paint(lk, F, true, C + 1, F - C, 1, C),
                                  side(lk, F, C, true),                  side(lk, F, C, false)};
    put(cr, pieces[0], x0, y0, cw, ch);
    put(cr, pieces[1], x1 - cw, y0, cw, ch);
    put(cr, pieces[2], x0, y1 - ch, cw, ch);
    put(cr, pieces[3], x1 - cw, y1 - ch, cw, ch);
    put(cr, pieces[4], x0 + cw, y0, W - 2 * cw, ch);
    put(cr, pieces[5], x0 + cw, y1 - ch, W - 2 * cw, ch);
    put(cr, pieces[6], x0, y0 + ch, cw, H - 2 * ch);
    put(cr, pieces[7], x1 - cw, y0 + ch, cw, H - 2 * ch);
    for (auto* p : pieces)
        cairo_surface_destroy(p);

    // the window, rounded as Hyprland rounds it: a cream terminal
    cairo_new_path(cr);
    roundRect(cr, x * s, y * s, w * s, h * s, lk.rounding * s);
    cairo_set_source_rgb(cr, 0.96, 0.93, 0.87);
    cairo_fill(cr);
}

int main(int argc, char** argv) {
    const std::string out   = argc > 1 ? argv[1] : "rim-preview.png";
    const double      scale = argc > 2 ? std::atof(argv[2]) : 1.0;
    const int         W = std::lround(1100 * scale), H = std::lround(620 * scale);

    auto* surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, W, H);
    auto* cr   = cairo_create(surf);
    if (argc > 3) {
        auto* bg = cairo_image_surface_create_from_png(argv[3]);
        if (cairo_surface_status(bg) == CAIRO_STATUS_SUCCESS) {
            cairo_scale(cr, (double)W / cairo_image_surface_get_width(bg), (double)H / cairo_image_surface_get_height(bg));
            cairo_set_source_surface(cr, bg, 0, 0);
            cairo_paint(cr);
            cairo_identity_matrix(cr);
        }
        cairo_surface_destroy(bg);
    } else {
        cairo_set_source_rgb(cr, 0.83, 0.63, 0.44);
        cairo_paint(cr);
    }

    SLook lk;
    lk.scale    = scale;
    lk.rounding = 9;
    lk.dim      = 0x521f1a14;
    lk.focused  = false;
    window(cr, lk, 35, 35, 500, 550);   // not in use
    lk.focused = true;
    window(cr, lk, 565, 35, 500, 550);  // in use

    cairo_destroy(cr);
    cairo_surface_write_to_png(surf, out.c_str());
    cairo_surface_destroy(surf);
    std::printf("%s\n", out.c_str());
    return 0;
}
