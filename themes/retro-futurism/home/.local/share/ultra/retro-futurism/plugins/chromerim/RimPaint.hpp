#pragma once

// The rim's drawing, apart from Hyprland: plain pixels into cairo surfaces,
// so it can be tried out on its own (preview.cpp draws windows with it).
//
// The rim is cut into pieces that are laid round a window of any size:
//
//   corners  K x K: the bend, and a little of the straight runs either side
//            of it (where the bend's glints fade out)
//   top, bottom   one pixel along, D deep: stretched along the straight runs
//   sides    D deep, SIDE_ROWS long: stretched down the window's sides
//
// Every pixel is shaded from where it lies in the rim: its depth (which of
// the taskbar's bands) and how far round the bend it is. On the straight
// runs a band has the colour the taskbar's rim has; round a bend the chrome
// turns away from the light and darkens, and just as it starts to turn it
// catches it: a glint, white at its heart with a soft bloom, as the taskbar's
// ends have. Each pixel is sampled 4 x 4 times, so the edges are smooth.

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
constexpr int    SIDE_ROWS = 64;
// how far a corner piece runs on along the straight, logical px
constexpr double RUN_ON = 26;
constexpr int    SS     = 4; // samples a side per pixel

// one look: the pieces for a monitor scale, a window rounding, in use or not
struct SLook {
    double   scale = 1, rounding = 0;
    bool     focused = true;
    double   width = 17, overlap = 1;
    uint32_t dim = 0;

    bool     operator==(const SLook&) const = default;
};

// the pieces' sizes, device px
struct SGeom {
    double T = 0, Ro = 0, Rm = 0; // the rim's depth, its outer radius, the radius along its middle
    int    K = 1, D = 1;          // a corner piece's side; the straight pieces' depth
};

inline SGeom geom(const SLook& lk) {
    SGeom g;
    const double s = lk.scale;
    g.T            = lk.width * s;
    g.Ro           = (std::max(0.0, lk.rounding) + lk.width) * s;
    g.Rm           = std::max(1.0, g.Ro - g.T / 2);
    g.K            = std::max(1, (int)std::ceil(g.Ro + RUN_ON * s));
    g.D            = std::max(1, (int)std::ceil(g.T));
    return g;
}

// ---- the light on the chrome. `phi` is how far round the bend a point is,
// in radians: 0 where the straight run along the top (or bottom) ends, pi/2
// where the side's begins; less than 0 back along the top, more than pi/2
// down the side.
struct SGlint {
    double phi, band, phiWidth, bandWidth, strength;
};
// on a top corner: a big one where the straight meets the curve, blooming
// over the rim's dark bands and a little back along the straight (the
// taskbar's ends have it there), and a small sharp one on the outer edge as
// the bend runs into the side
constexpr std::array<SGlint, 3> TOP_GLINTS  = {SGlint{0.18, 7.0, 0.24, 4.5, 1.25}, SGlint{0.30, 12.5, 0.10, 2.0, 0.9},
                                               SGlint{1.30, 3.0, 0.13, 2.2, 0.75}};
// on a bottom corner: one on its bright band low in the bend, and a small
// one on the outer edge
constexpr std::array<SGlint, 2> FOOT_GLINTS = {SGlint{0.30, 13.0, 0.22, 3.6, 1.1}, SGlint{1.20, 3.5, 0.12, 2.0, 0.6}};

inline double smoothstep(double a, double b, double x) {
    const double t = std::clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3 - 2 * t);
}

inline void rgbOf(uint32_t c, double out[3]) {
    out[0] = ((c >> 16) & 0xff) / 255.0;
    out[1] = ((c >> 8) & 0xff) / 255.0;
    out[2] = (c & 0xff) / 255.0;
}

// the rim's colour at `depth` device px in from its outer edge, `phi` round
// the bend; foot: a bottom corner. The side's own colour (t: 0 its head, 1
// its foot) comes from side() below.
inline void shade(const SLook& lk, const SGeom& g, double depth, double phi, bool foot, double out[3]) {
    const double bandF = std::clamp(depth / g.T * BANDS, 0.0, BANDS - 1e-6);
    rgbOf((foot ? FOOT : TOP)[(int)bandF], out);

    // round the bend the chrome turns from the light: in the bend's middle
    // the outer bands dim, and the inner ones (the groove) run dark, nearly
    // black, as the taskbar's ends do
    const double mid    = foot ? 0.85 : 0.92;
    const double inBend = std::exp(-std::pow((phi - mid) / 0.40, 2));
    const double groove = std::exp(-std::pow((bandF - 13.0) / 3.2, 2)); // the inner dark bands
    const double k      = inBend * ((foot ? 0.22 : 0.28) + (foot ? 0.45 : 0.6) * groove);
    for (int i = 0; i < 3; ++i)
        out[i] *= 1 - std::min(0.85, k);

    // and just as it turns, it catches the light
    double glow = 0;
    auto   add  = [&](const SGlint& gl) {
        glow += gl.strength * std::exp(-std::pow((phi - gl.phi) / gl.phiWidth, 2) - std::pow((bandF - gl.band) / gl.bandWidth, 2));
    };
    if (foot)
        for (const auto& gl : FOOT_GLINTS)
            add(gl);
    else
        for (const auto& gl : TOP_GLINTS)
            add(gl);
    glow = std::min(1.0, glow);
    for (int i = 0; i < 3; ++i)
        out[i] += (1 - out[i]) * glow;
}

// a side, `t` of the way down: the top rim's colours held a while, then
// running into the bottom rim's
inline void sideShade(const SGeom& g, double depth, double t, double out[3]) {
    const int    band = (int)std::clamp(depth / g.T * BANDS, 0.0, BANDS - 1e-6);
    const double w    = smoothstep(0.25, 1.0, t);
    double       a[3], b[3];
    rgbOf(TOP[band], a);
    rgbOf(FOOT[band], b);
    for (int i = 0; i < 3; ++i)
        out[i] = a[i] * (1 - w) + b[i] * w;
}

// a window not in use: the dim colour laid over the rim at its alpha (still solid)
inline void dimmed(const SLook& lk, double c[3]) {
    if (lk.focused)
        return;
    const double k = ((lk.dim >> 24) & 0xff) / 255.0;
    double       d[3];
    rgbOf(lk.dim, d);
    for (int i = 0; i < 3; ++i)
        c[i] = c[i] * (1 - k) + d[i] * k;
}

// Fill a w x h ARGB32 surface: `at(x, y, rgb)` gives the colour at a point
// of the piece and whether the point is on the rim at all.
template <typename F>
inline cairo_surface_t* fill(int w, int h, F at) {
    auto*      surf   = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    const int  stride = cairo_image_surface_get_stride(surf);
    auto*      data   = cairo_image_surface_get_data(surf);
    cairo_surface_flush(surf);
    for (int y = 0; y < h; ++y) {
        auto* row = reinterpret_cast<uint32_t*>(data + y * stride);
        for (int x = 0; x < w; ++x) {
            double acc[3] = {0, 0, 0}, cov = 0;
            for (int sy = 0; sy < SS; ++sy) {
                for (int sx = 0; sx < SS; ++sx) {
                    double c[3];
                    if (!at(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS, c))
                        continue;
                    for (int i = 0; i < 3; ++i)
                        acc[i] += c[i];
                    cov += 1;
                }
            }
            const double a = cov / (SS * SS);
            // (premultiplied: the sum of the samples on the rim over all samples)
            auto byte = [](double v) { return (uint32_t)std::lround(std::clamp(v, 0.0, 1.0) * 255); };
            row[x]    = (byte(a) << 24) | (byte(acc[0] / (SS * SS)) << 16) | (byte(acc[1] / (SS * SS)) << 8) | byte(acc[2] / (SS * SS));
        }
    }
    cairo_surface_mark_dirty(surf);
    return surf;
}

// a corner: 0 top left, 1 top right, 2 bottom left, 3 bottom right
inline cairo_surface_t* corner(const SLook& lk, int which) {
    const SGeom g     = geom(lk);
    const bool  right = which == 1 || which == 3, foot = which >= 2;
    return fill(g.K, g.K, [&](double px, double py, double c[3]) {
        // as the top left corner: x, y from the rim's outer corner
        const double x = right ? g.K - px : px, y = foot ? g.K - py : py;
        double       depth, phi;
        if (x < g.Ro && y < g.Ro) {
            depth = g.Ro - std::hypot(g.Ro - x, g.Ro - y);
            phi   = std::atan2(g.Ro - x, g.Ro - y);
        } else if (x >= g.Ro && y < g.Ro) {
            depth = y;
            phi   = -(x - g.Ro) / g.Rm;
        } else if (y >= g.Ro && x < g.Ro) {
            depth = x;
            phi   = M_PI / 2 + (y - g.Ro) / g.Rm;
        } else
            return false;
        if (depth < 0 || depth >= g.T)
            return false;
        shade(lk, g, depth, phi, foot, c);
        dimmed(lk, c);
        return true;
    });
}

// the top's straight run (foot: the bottom's), a pixel along
inline cairo_surface_t* run(const SLook& lk, bool foot) {
    const SGeom g = geom(lk);
    return fill(1, g.D, [&](double, double py, double c[3]) {
        const double depth = foot ? g.D - py : py;
        if (depth < 0 || depth >= g.T)
            return false;
        shade(lk, g, depth, -100, foot, c);
        dimmed(lk, c);
        return true;
    });
}

// a side (right: the right one), SIDE_ROWS long, head to foot
inline cairo_surface_t* side(const SLook& lk, bool right) {
    const SGeom g = geom(lk);
    return fill(g.D, SIDE_ROWS, [&](double px, double py, double c[3]) {
        const double depth = right ? g.D - px : px;
        if (depth < 0 || depth >= g.T)
            return false;
        sideShade(g, depth, std::clamp((py - 0.5) / (SIDE_ROWS - 1), 0.0, 1.0), c);
        dimmed(lk, c);
        return true;
    });
}

}
