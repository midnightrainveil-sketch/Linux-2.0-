#pragma once

// The rim's drawing, apart from Hyprland: cairo only, so it can be tried
// out on its own (tools/rim_preview.cpp draws a window with it).
//
// A rim is drawn whole, F x F device px, and cut into pieces: the four
// corners and a one-pixel slice of the top and bottom; the sides get a
// strip whose colour runs from the top rim's to the bottom rim's.

#include <cairo/cairo.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

namespace RimPaint {

// The taskbar's rim from the outside in, as the mock-up has it (22 px
// deep there, its inner lip included): the colour of its top rim at each
// depth, and of its bottom rim. (Read off art/TaskbarEg.png, the mean of
// x 1060-1140, at y 320-341 and 418-397; the shell's components/Frame.qml
// has the same table.)
constexpr int                         BANDS = 22;
constexpr std::array<uint32_t, BANDS> TOP   = {0xcac7c3, 0x878075, 0xe0d9d0, 0xcbc2b9, 0xd6cdc4, 0xece6de, 0xf9f7f1, 0xfcfcf8,
                                              0xfffefd, 0xf2f0ec, 0x918679, 0x5f5447, 0x685f52, 0x4b4035, 0x493c30, 0x7e7263,
                                              0x8b7d6c, 0x8b7b66, 0xd5cab2, 0xb6a88d, 0x96886c, 0xa29a81};
constexpr std::array<uint32_t, BANDS> FOOT  = {0x4a4a47, 0x1a1a17, 0x23211d, 0x4b473f, 0x58534a, 0x706b62, 0x76716a, 0x76716a,
                                              0x6b655e, 0x534b45, 0x98938d, 0xfffffe, 0xf4f3f2, 0xf5f4f1, 0xf2f1ed, 0xe3e0dc,
                                              0xd8d5d0, 0xc0c0ba, 0x4e4a40, 0x8d806e, 0xf2dfc7, 0xc9b9a1};

// rows in a side's piece: its colour runs from the top rim's to the
// bottom rim's down the window's side (stretched to fit, smoothly)
constexpr int SIDE_ROWS = 64;

// one look: the pieces for a monitor scale, a window rounding, in use or not
struct SLook {
    double scale = 1, rounding = 0;
    bool   focused = true;
    double width = 17, overlap = 1;
    uint32_t dim = 0;

    bool   operator==(const SLook&) const = default;
};

// a corner piece's side (and a side piece's depth), device px
inline int cornerSize(const SLook& lk) {
    return std::max(1, (int)std::ceil((std::max(0.0, lk.rounding) + lk.width) * lk.scale));
}

// a colour of the rim, darkened for a window not in use: the dim colour
// laid over it at its alpha (still solid)
inline void bandColour(uint32_t rgb, const SLook& lk, double out[3]) {
    double c[3] = {((rgb >> 16) & 0xff) / 255.0, ((rgb >> 8) & 0xff) / 255.0, (rgb & 0xff) / 255.0};
    if (!lk.focused) {
        const double k    = ((lk.dim >> 24) & 0xff) / 255.0;
        const double d[3] = {((lk.dim >> 16) & 0xff) / 255.0, ((lk.dim >> 8) & 0xff) / 255.0, (lk.dim & 0xff) / 255.0};
        for (int i = 0; i < 3; ++i)
            c[i] = c[i] * (1 - k) + d[i] * k;
    }
    for (int i = 0; i < 3; ++i)
        out[i] = c[i];
}

inline void roundRect(cairo_t* cr, double x, double y, double w, double h, double r) {
    r = std::clamp(r, 0.0, std::min(w, h) / 2);
    cairo_new_sub_path(cr);
    if (r <= 0) {
        cairo_rectangle(cr, x, y, w, h);
        return;
    }
    cairo_arc(cr, x + w - r, y + r, r, -M_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, M_PI / 2, M_PI);
    cairo_arc(cr, x + r, y + r, r, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);
}

// A whole rim, F x F device px, in the top rim's colours or the bottom's,
// painted into a w x h piece whose corner sits at (ox, oy) of it. Each
// band runs from its depth to the rim's inner edge and the next is laid
// over it, so only the outer edge is soft and the rim is solid.
inline cairo_surface_t* paint(const SLook& lk, int F, bool foot, int ox, int oy, int w, int h) {
    auto*        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    auto*        cr   = cairo_create(surf);
    const double s = lk.scale, T = lk.width * s, Ri = std::max(0.0, lk.rounding) * s, Ro = Ri + T, u = T / BANDS;

    cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
    cairo_translate(cr, -ox, -oy);
    cairo_set_fill_rule(cr, CAIRO_FILL_RULE_EVEN_ODD);

    for (int d = 0; d < BANDS; ++d) {
        double c[3];
        bandColour(foot ? FOOT[d] : TOP[d], lk, c);
        cairo_set_source_rgb(cr, c[0], c[1], c[2]);
        cairo_new_path(cr);
        roundRect(cr, d * u, d * u, F - 2 * d * u, F - 2 * d * u, Ro - d * u);
        roundRect(cr, T, T, F - 2 * T, F - 2 * T, Ri);
        cairo_fill(cr);
    }

    cairo_destroy(cr);
    cairo_surface_flush(surf);
    return surf;
}

// a side's piece: C px deep, SIDE_ROWS long, the top rim's colours at
// its head and the bottom rim's at its foot
inline cairo_surface_t* side(const SLook& lk, int F, int C, bool left) {
    const int x    = left ? 0 : F - C;
    auto*     head = paint(lk, F, false, x, C + 1, C, 1);
    auto*     foot = paint(lk, F, true, x, C + 1, C, 1);
    auto*     surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, C, SIDE_ROWS);
    cairo_surface_flush(surf);

    const auto* a      = cairo_image_surface_get_data(head);
    const auto* b      = cairo_image_surface_get_data(foot);
    auto*       out    = cairo_image_surface_get_data(surf);
    const int   stride = cairo_image_surface_get_stride(surf);
    for (int r = 0; r < SIDE_ROWS; ++r) {
        const double t = (double)r / (SIDE_ROWS - 1);
        for (int i = 0; i < C * 4; ++i)
            out[r * stride + i] = (unsigned char)std::lround(a[i] * (1 - t) + b[i] * t);
    }
    cairo_surface_mark_dirty(surf);
    cairo_surface_destroy(head);
    cairo_surface_destroy(foot);
    return surf;
}

}
