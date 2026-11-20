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
#include <fstream>
#include <string>

namespace RimPaint {

// The rim's profile, outer edge (0) to inner edge (1): how light the chrome
// is at each depth, along the top (lit from above) and along the foot (its
// underside). Read off the taskbar's rim in the mock-up (art/TaskbarEg.png,
// x 1000-1200, y 320-341 and 418-397) and made one material: neutral
// chrome, a smooth curve between the points (no steps), its dark band
// lifted to where the taskbar's reads (it is a reflection, not a darker
// metal), and the tube rolled back up into a thin bright lip at the window,
// as the taskbar's closes against its face. SHOWN: how many of the taskbar's
// 1-px bands the rim's depth stands for (the glints are placed in those).
struct SKey {
    double at, light;
};
constexpr std::array<SKey, 15> TOP_CURVE = {SKey{0.00, 0.78}, SKey{0.05, 0.56}, SKey{0.10, 0.86}, SKey{0.20, 0.84}, SKey{0.30, 0.93},
                                            SKey{0.40, 0.99}, SKey{0.50, 0.96}, SKey{0.56, 0.70}, SKey{0.63, 0.56}, SKey{0.72, 0.50},
                                            SKey{0.80, 0.55}, SKey{0.86, 0.66}, SKey{0.92, 0.90}, SKey{0.97, 0.78}, SKey{1.00, 0.62}};
constexpr std::array<SKey, 14> FOOT_CURVE = {SKey{0.00, 0.46}, SKey{0.06, 0.34}, SKey{0.14, 0.38}, SKey{0.26, 0.46}, SKey{0.38, 0.52},
                                             SKey{0.46, 0.50}, SKey{0.52, 0.66}, SKey{0.57, 0.97}, SKey{0.72, 0.95}, SKey{0.82, 0.87},
                                             SKey{0.88, 0.76}, SKey{0.92, 0.66}, SKey{0.96, 0.88}, SKey{1.00, 0.66}};
constexpr int SHOWN = 18;

template <size_t N>
inline double curveAt(const std::array<SKey, N>& c, double f) {
    if (f <= c[0].at)
        return c[0].light;
    for (size_t i = 1; i < N; ++i) {
        if (f <= c[i].at) {
            const double t = (f - c[i - 1].at) / (c[i].at - c[i - 1].at);
            const double s = t * t * (3 - 2 * t);               // (eased: no corners in the curve)
            return c[i - 1].light + (c[i].light - c[i - 1].light) * s;
        }
    }
    return c[N - 1].light;
}

// chrome of a lightness: a whisper warm, as the taskbar's (no hue of its own)
inline void chromeOf(double light, double out[3]) {
    out[0] = std::clamp(light * 1.000 + 0.004, 0.0, 1.0);
    out[1] = std::clamp(light * 0.990 + 0.002, 0.0, 1.0);
    out[2] = std::clamp(light * 0.972, 0.0, 1.0);
}

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
constexpr std::array<SGlint, 3> TOP_GLINTS  = {SGlint{0.18, 7.0, 0.27, 5.0, 1.5}, SGlint{0.30, 12.5, 0.11, 2.2, 1.1},
                                               SGlint{1.30, 3.0, 0.14, 2.4, 0.95}};
// on a bottom corner: one on its bright band low in the bend, and a small
// one on the outer edge
constexpr std::array<SGlint, 2> FOOT_GLINTS = {SGlint{0.30, 13.0, 0.24, 4.0, 1.35}, SGlint{1.20, 3.5, 0.13, 2.2, 0.8}};

inline double smoothstep(double a, double b, double x) {
    const double t = std::clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3 - 2 * t);
}

// more chrome than the picture: its lights pushed towards white, its darks
// left as the taskbar has them (deepened, the groove read as a black ring)
inline void chromed(double c[3]) {
    const double lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    const double hot = smoothstep(0.70, 0.93, lum) * 0.75;         // the bright bands: nearly white
    for (int i = 0; i < 3; ++i) {
        double v = c[i] > 0.55 ? 0.55 + (c[i] - 0.55) * 1.35 : c[i];   // contrast above the mid-tones only
        v        = v + (1 - v) * hot;
        c[i]     = std::clamp(v, 0.0, 1.0);
    }
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
    const double f     = std::clamp(depth / g.T, 0.0, 1.0);
    const double bandF = f * SHOWN;
    chromeOf(foot ? curveAt(FOOT_CURVE, f) : curveAt(TOP_CURVE, f), out);
    chromed(out);

    // round the bend the chrome turns from the light: in the bend's middle
    // the outer bands dim, and the inner ones (the groove) run dark, nearly
    // black, as the taskbar's ends do
    const double mid    = foot ? 0.85 : 0.92;
    const double inBend = std::exp(-std::pow((phi - mid) / 0.40, 2));
    const double groove = std::exp(-std::pow((bandF - 13.0) / 3.2, 2)); // the inner dark bands
    const double k      = inBend * ((foot ? 0.18 : 0.22) + (foot ? 0.22 : 0.26) * groove);
    for (int i = 0; i < 3; ++i)
        out[i] *= 1 - std::min(0.45, k);

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
    const double f = std::clamp(depth / g.T, 0.0, 1.0);
    const double w = smoothstep(0.25, 1.0, t);
    chromeOf(curveAt(TOP_CURVE, f) * (1 - w) + curveAt(FOOT_CURVE, f) * w, out);
    chromed(out);
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


// ---------------------------------------------------------------- the rim, from the taskbar
//
// The rim cut from the taskbar's own picture (tools/make_rim.py): its ends'
// quarters for the corners, its straights for the top and bottom, the
// middle of its ends for the sides. Laid round a window as they are; only
// scaled to the rim's width and the monitor's scale (and darkened for a
// window not in use). When they are not there, the rim is drawn as above.

struct SArt {
    bool             ok    = false;
    int              depth = 22, n = 84;          // the rim's depth and a corner piece's side, in the pieces' pixels
    cairo_surface_t* piece[8] = {};               // corners tl tr bl br, top, bottom, left, right
};

inline void freeArt(SArt& art) {
    for (auto*& p : art.piece) {
        if (p)
            cairo_surface_destroy(p);
        p = nullptr;
    }
    art.ok = false;
}

inline SArt loadArt(const std::string& dir) {
    SArt art;
    if (dir.empty())
        return art;
    std::ifstream meta(dir + "/rim.txt");
    std::string   key;
    double        v;
    while (meta >> key >> v) {
        if (key == "depth")
            art.depth = (int)v;
        else if (key == "corner")
            art.n = (int)v;
    }
    const char* names[8] = {"corner-tl", "corner-tr", "corner-bl", "corner-br", "top", "bottom", "left", "right"};
    for (int i = 0; i < 8; ++i) {
        art.piece[i] = cairo_image_surface_create_from_png((dir + "/" + names[i] + ".png").c_str());
        if (cairo_surface_status(art.piece[i]) != CAIRO_STATUS_SUCCESS) {
            freeArt(art);
            return art;
        }
    }
    art.ok = art.depth > 0 && art.n > 0;
    return art;
}

// device px per piece px for a look
inline double artScale(const SArt& art, const SLook& lk) {
    return lk.width * lk.scale / art.depth;
}
inline int artDepth(const SArt& art, const SLook& lk);
// (the corner from the straights' depth, so both scale alike: a corner
// piece is a whole number of rims deep, tools/make_rim.py)
inline int artCorner(const SArt& art, const SLook& lk) {
    return std::max(1, (int)std::lround((double)art.n / art.depth * artDepth(art, lk)));
}
inline int artDepth(const SArt& art, const SLook& lk) {
    return std::max(1, (int)std::lround(art.depth * artScale(art, lk)));
}

// a piece scaled to w x h device px, darkened as a window not in use has it
inline cairo_surface_t* artPiece(const SArt& art, int which, const SLook& lk, int w, int h) {
    auto*        src  = art.piece[which];
    auto*        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    auto*        cr   = cairo_create(surf);
    const double sw = cairo_image_surface_get_width(src), sh = cairo_image_surface_get_height(src);
    cairo_scale(cr, w / sw, h / sh);
    cairo_set_source_surface(cr, src, 0, 0);
    cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_BEST);
    cairo_pattern_set_extend(cairo_get_source(cr), CAIRO_EXTEND_PAD);
    cairo_paint(cr);
    if (!lk.focused && ((lk.dim >> 24) & 0xff) > 0) {
        double d[3];
        rgbOf(lk.dim, d);
        cairo_identity_matrix(cr);
        cairo_set_operator(cr, CAIRO_OPERATOR_ATOP);
        cairo_set_source_rgba(cr, d[0], d[1], d[2], ((lk.dim >> 24) & 0xff) / 255.0);
        cairo_paint(cr);
    }
    cairo_destroy(cr);
    cairo_surface_flush(surf);
    return surf;
}

}
