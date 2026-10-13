#include "deckle.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

namespace Deckle {

    // ---------------------------------------------------------------- noise

    static uint32_t mix(uint32_t x) {
        x ^= x >> 16;
        x *= 0x7feb352dU;
        x ^= x >> 15;
        x *= 0x846ca68bU;
        x ^= x >> 16;
        return x;
    }

    static double random01(uint32_t a, uint32_t b, uint32_t c) {
        return mix(mix(mix(a) ^ (b * 0x9e3779b9U)) ^ (c * 0x85ebca6bU)) / 4294967296.0;
    }

    // Smooth value noise that repeats exactly every `length`: the lattice is
    // rounded so a whole number of cells fits.
    static double periodicNoise(double u, double length, double spacing, uint32_t seed, uint32_t salt) {
        const int    cells = std::max(1, (int)std::lround(length / spacing));
        const double cell  = length / cells;
        const double t     = u / cell;
        const int    i     = (int)std::floor(t);
        double       f     = t - i;
        f                  = f * f * (3 - 2 * f);
        auto value         = [&](int j) {
            j = ((j % cells) + cells) % cells;
            return random01(seed, salt, (uint32_t)j) * 2 - 1;
        };
        return value(i) * (1 - f) + value(i + 1) * f;
    }

    // One edge's character along its length: how far it wanders (outward is
    // positive), how heavy and how dark the rim is. All three return to the
    // same values at both ends, so any two edges can be joined end to end.
    struct SProfile {
        double              length = 0;
        double              step   = 0.5;
        std::vector<double> offset, width, alpha;

        static double sample(const std::vector<double>& v, double step, double u) {
            if (v.empty())
                return 0;
            const double t = u / step;
            if (t <= 0)
                return v.front();
            if (t >= v.size() - 1)
                return v.back();
            const int    i = (int)t;
            const double f = t - i;
            return v[i] * (1 - f) + v[i + 1] * f;
        }

        double offsetAt(double u) const {
            return (u <= 0 || u >= length) ? 0 : sample(offset, step, u);
        }
        double widthAt(double u) const {
            return sample(width, step, std::clamp(u, 0.0, length));
        }
        double alphaAt(double u) const {
            return sample(alpha, step, std::clamp(u, 0.0, length));
        }
    };

    static SProfile makeProfile(const SStyle& st, double length, uint32_t seed) {
        SProfile p;
        p.length    = length;
        const int n = std::max(2, (int)std::ceil(length / 0.5));
        p.step      = length / n;

        auto wander = [&](double u) {
            return 0.55 * periodicNoise(u, length, 46, seed, 1)   // slow wave of the cut
                + 0.30 * periodicNoise(u, length, 11, seed, 2)    // unevenness
                + 0.38 * periodicNoise(u, length, 2.2, seed, 3)   // the paper's tooth
                + 0.18 * periodicNoise(u, length, 0.9, seed, 4);  // loose fibres
        };
        auto heft = [&](double u) { return periodicNoise(u, length, 7, seed, 5); };
        auto ink  = [&](double u) { return 0.5 * periodicNoise(u, length, 5, seed, 6) + 0.5 * periodicNoise(u, length, 1.1, seed, 7); };

        const double w0 = wander(0), h0 = heft(0), i0 = ink(0);
        for (int k = 0; k <= n; ++k) {
            const double u = k * p.step;
            p.offset.push_back(st.amplitude * (wander(u) - w0));
            p.width.push_back(st.rimWidth * std::clamp(0.9 + 0.4 * (heft(u) - h0), 0.45, 1.7));
            p.alpha.push_back(std::clamp(0.8 + 0.6 * (ink(u) - i0), 0.25, 1.0));
        }
        return p;
    }

    // ---------------------------------------------------------------- helpers

    struct SPoint {
        double x, y;
    };

    static void setColor(cairo_t* cr, uint32_t argb, double alphaMul = 1.0) {
        cairo_set_source_rgba(cr, ((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0, (argb & 0xff) / 255.0, ((argb >> 24) & 0xff) / 255.0 * alphaMul);
    }

    static void polygon(cairo_t* cr, const std::vector<SPoint>& pts) {
        cairo_new_path(cr);
        for (size_t i = 0; i < pts.size(); ++i) {
            if (i == 0)
                cairo_move_to(cr, pts[i].x, pts[i].y);
            else
                cairo_line_to(cr, pts[i].x, pts[i].y);
        }
        cairo_close_path(cr);
    }

    // three box passes per axis (close to a gaussian), on an alpha-only surface
    static void blur(cairo_surface_t* surf, int radius) {
        if (radius < 1)
            return;
        cairo_surface_flush(surf);
        const int            w = cairo_image_surface_get_width(surf), h = cairo_image_surface_get_height(surf);
        const int            stride = cairo_image_surface_get_stride(surf);
        uint8_t*             data   = cairo_image_surface_get_data(surf);
        const int            span   = 2 * radius + 1;
        std::vector<int32_t> line(std::max(w, h)), out(std::max(w, h));

        auto                 pass = [&](uint8_t* first, int len, int step) {
            for (int i = 0; i < len; ++i)
                line[i] = first[i * step];
            for (int rep = 0; rep < 3; ++rep) {
                int sum = 0;
                for (int i = 0; i <= radius && i < len; ++i)
                    sum += line[i];
                for (int i = 0; i < len; ++i) {
                    out[i] = (sum + span / 2) / span;
                    if (i + radius + 1 < len)
                        sum += line[i + radius + 1];
                    if (i - radius >= 0)
                        sum -= line[i - radius];
                }
                std::swap(line, out);
            }
            for (int i = 0; i < len; ++i)
                first[i * step] = (uint8_t)std::clamp(line[i], 0, 255);
        };

        for (int y = 0; y < h; ++y)
            pass(data + y * stride, w, 1);
        for (int x = 0; x < w; ++x)
            pass(data + x, h, stride);
        cairo_surface_mark_dirty(surf);
    }

    int SStyle::outset() const {
        return (int)std::ceil(3 * shadowBlur + std::max(std::abs(shadowX), std::abs(shadowY)) + amplitude + rimWidth + 1);
    }

    // A tile is drawn on a larger canvas (so the shadow blur sees what lies
    // past the tile's ends), then cropped.
    struct SCanvas {
        cairo_surface_t* surf = nullptr;
        cairo_t*         cr   = nullptr;
        int              pad  = 0; // device pixels around the tile
        int              tw = 0, th = 0;

        SCanvas(const SStyle& st, double w, double h, int padLogical) {
            tw   = std::max(1, (int)std::lround(w * st.scale));
            th   = std::max(1, (int)std::lround(h * st.scale));
            pad  = (int)std::ceil(padLogical * st.scale);
            surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, tw + 2 * pad, th + 2 * pad);
            cr   = cairo_create(surf);
            cairo_translate(cr, pad, pad);
            cairo_scale(cr, tw / w, th / h);
            cairo_set_antialias(cr, CAIRO_ANTIALIAS_GOOD);
        }

        cairo_surface_t* crop() {
            cairo_destroy(cr);
            cairo_surface_flush(surf);
            cairo_surface_t* tile = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, tw, th);
            cairo_t*         c    = cairo_create(tile);
            cairo_set_operator(c, CAIRO_OPERATOR_SOURCE);
            cairo_set_source_surface(c, surf, -pad, -pad);
            cairo_paint(c);
            cairo_destroy(c);
            cairo_surface_destroy(surf);
            cairo_surface_flush(tile);
            return tile;
        }
    };

    // the paper shape as an alpha mask, offset and softened
    static cairo_surface_t* shadowMask(const SCanvas& cv, const std::vector<SPoint>& shape, double dx, double dy, int radius) {
        cairo_surface_t* mask = cairo_image_surface_create(CAIRO_FORMAT_A8, cairo_image_surface_get_width(cv.surf), cairo_image_surface_get_height(cv.surf));
        cairo_t*         mc   = cairo_create(mask);
        cairo_matrix_t   m;
        cairo_get_matrix(cv.cr, &m);
        cairo_set_matrix(mc, &m);
        cairo_translate(mc, dx, dy);
        polygon(mc, shape);
        cairo_set_source_rgba(mc, 0, 0, 0, 1);
        cairo_fill(mc);
        cairo_destroy(mc);
        blur(mask, radius);
        return mask;
    }

    // the soft shadow of the paper shape, a tight one right under its edge,
    // then the paper over both
    static void shadowAndPaper(SCanvas& cv, const SStyle& st, const std::vector<SPoint>& shape) {
        cairo_t*         cr    = cv.cr;
        cairo_surface_t* soft  = shadowMask(cv, shape, st.shadowX, st.shadowY, (int)std::lround(st.shadowBlur * st.scale));
        cairo_surface_t* tight = st.contact > 0 ? shadowMask(cv, shape, 0, st.contactY, std::max(1, (int)std::lround(0.8 * st.scale))) : nullptr;
        cairo_save(cr);
        cairo_identity_matrix(cr); // the masks are in device pixels
        setColor(cr, st.shadow);
        cairo_mask_surface(cr, soft, 0, 0);
        if (tight) {
            setColor(cr, st.shadow, st.contact);
            cairo_mask_surface(cr, tight, 0, 0);
            cairo_surface_destroy(tight);
        }
        cairo_surface_destroy(soft);
        cairo_restore(cr);

        polygon(cr, shape);
        setColor(cr, st.paper | 0xff000000);
        cairo_fill(cr);
    }

    // a line along `pts`, clipped to the paper
    static void bevel(cairo_t* cr, const SStyle& st, const std::vector<SPoint>& pts, const std::vector<SPoint>& shape, double strength) {
        if (pts.size() < 2 || strength <= 0)
            return;
        cairo_save(cr);
        polygon(cr, shape);
        cairo_clip(cr);
        cairo_new_path(cr);
        cairo_move_to(cr, pts[0].x, pts[0].y);
        for (size_t i = 1; i < pts.size(); ++i)
            cairo_line_to(cr, pts[i].x, pts[i].y);
        setColor(cr, st.bevel, strength);
        cairo_set_line_width(cr, 1.4);
        cairo_set_line_join(cr, CAIRO_LINE_JOIN_ROUND);
        cairo_stroke(cr);
        cairo_restore(cr);
    }

    // the rim: short segments, each with its own weight and darkness
    static void rim(cairo_t* cr, const std::vector<SPoint>& pts, const std::vector<double>& widths, const std::vector<double>& alphas, uint32_t color) {
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_BUTT);
        for (size_t i = 1; i < pts.size(); ++i) {
            cairo_new_path(cr);
            cairo_move_to(cr, pts[i - 1].x, pts[i - 1].y);
            cairo_line_to(cr, pts[i].x, pts[i].y);
            cairo_set_line_width(cr, (widths[i - 1] + widths[i]) / 2);
            setColor(cr, color, (alphas[i - 1] + alphas[i]) / 2);
            cairo_stroke(cr);
        }
    }

    static uint32_t rimColor(const SStyle& st, eSide side) {
        if (side == SIDE_TOP)
            return st.rimTop;
        if (side == SIDE_BOTTOM)
            return st.rimBottom;
        // the sides are lit more like the top than the bottom
        uint32_t out = 0;
        for (int c = 0; c < 32; c += 8)
            out |= (uint32_t)std::lround(((st.rimTop >> c) & 0xff) * 0.65 + ((st.rimBottom >> c) & 0xff) * 0.35) << c;
        return out;
    }

    static double bevelStrength(eSide side) {
        switch (side) {
            case SIDE_TOP: return 0.75;
            case SIDE_BOTTOM: return 0.12;
            default: return 0.15;
        }
    }

    // ---------------------------------------------------------------- strips

    cairo_surface_t* strip(const SStyle& st, eSide side, int variant) {
        const double   P = st.period, O = st.outset(), I = st.inset();
        const double   B = O + 2; // blur room past the tile's ends
        const bool     horizontal = side == SIDE_TOP || side == SIDE_BOTTOM;
        const SProfile prof       = makeProfile(st, P, 7919U * (side + 1) + 104729U * (variant + 1));

        // (u along the side, n inward from the card edge) -> tile coordinates
        auto map = [&](double u, double n) -> SPoint {
            switch (side) {
                case SIDE_TOP: return {u, O + n};
                case SIDE_BOTTOM: return {u, I - n};
                case SIDE_LEFT: return {O + n, u};
                default: return {I - n, u};
            }
        };

        SCanvas             cv(st, horizontal ? P : O + I, horizontal ? O + I : P, (int)std::ceil(B));
        cairo_t*            cr = cv.cr;

        std::vector<SPoint> edge, inner, shape;
        std::vector<double> widths, alphas;
        for (double u = -B; u <= P + B + 1e-6; u += prof.step) {
            const double off = prof.offsetAt(u);
            edge.push_back(map(u, -off));
            widths.push_back(prof.widthAt(u));
            alphas.push_back(prof.alphaAt(u));
            inner.push_back(map(u, -off + prof.widthAt(u) / 2 + 1.0));
        }
        shape = edge;
        shape.push_back(map(P + B, I + B));
        shape.push_back(map(-B, I + B));

        shadowAndPaper(cv, st, shape);
        bevel(cr, st, inner, shape, bevelStrength(side));
        rim(cr, edge, widths, alphas, rimColor(st, side));

        return cv.crop();
    }

    // ---------------------------------------------------------------- corners

    cairo_surface_t* corner(const SStyle& st, eCorner which, int variant) {
        const double O = st.outset(), R = st.cornerReach(), K = st.cornerSize();
        const double B = O + 2;
        const bool   right  = which == CORNER_TR || which == CORNER_BR;
        const bool   bottom = which == CORNER_BL || which == CORNER_BR;

        // both edges of the corner, each pinned to the baseline at its far end
        // (where a strip takes over) and at the corner itself
        const SProfile horiz = makeProfile(st, R, 31337U * (which + 1) + 7U * (variant + 1));
        const SProfile vert  = makeProfile(st, R, 92821U * (which + 1) + 13U * (variant + 1));

        // drawn as the top-left corner, then mirrored into place
        auto map = [&](double x, double y) -> SPoint { return {right ? K - x : x, bottom ? K - y : y}; };

        SCanvas             cv(st, K, K, (int)std::ceil(B));
        cairo_t*            cr = cv.cr;

        const double        wear = 0.6; // the very corner is a little blunted
        std::vector<SPoint> edge, innerV, innerH, shape;
        std::vector<double> widths, alphas;

        // down the side, from below the tile up to the corner
        for (double v = R + B; v >= wear - 1e-6; v -= vert.step) {
            const double off = vert.offsetAt(v);
            edge.push_back(map(O - off, O + v));
            widths.push_back(vert.widthAt(v));
            alphas.push_back(vert.alphaAt(v));
            innerV.push_back(map(O - off + vert.widthAt(v) / 2 + 1.0, O + std::max(v, 1.4)));
        }
        const size_t edgeSplit = edge.size() - 1;
        // along the top, from the corner out past the tile
        for (double u = wear; u <= R + B + 1e-6; u += horiz.step) {
            const double off = horiz.offsetAt(u);
            edge.push_back(map(O + u, O - off));
            widths.push_back(horiz.widthAt(u));
            alphas.push_back(horiz.alphaAt(u));
            innerH.push_back(map(O + std::max(u, 1.4), O - off + horiz.widthAt(u) / 2 + 1.0));
        }
        shape = edge;
        shape.push_back(map(K + B, K + B));

        shadowAndPaper(cv, st, shape);
        bevel(cr, st, innerH, shape, bevelStrength(bottom ? SIDE_BOTTOM : SIDE_TOP));
        bevel(cr, st, innerV, shape, bevelStrength(SIDE_LEFT));
        // the side's colour up to the corner, then the top or bottom colour
        const size_t split = edgeSplit;
        rim(cr, std::vector<SPoint>(edge.begin(), edge.begin() + split + 1), std::vector<double>(widths.begin(), widths.begin() + split + 1),
            std::vector<double>(alphas.begin(), alphas.begin() + split + 1), rimColor(st, SIDE_LEFT));
        rim(cr, std::vector<SPoint>(edge.begin() + split, edge.end()), std::vector<double>(widths.begin() + split, widths.end()),
            std::vector<double>(alphas.begin() + split, alphas.end()), rimColor(st, bottom ? SIDE_BOTTOM : SIDE_TOP));

        return cv.crop();
    }

    // ---------------------------------------------------------------- layout

    int variantFor(uint32_t seed, eSide side, int index) {
        return (int)(mix(seed * 4U + side + 1U) ^ mix((uint32_t)index * 0x27d4eb2dU + 3U)) % VARIANTS;
    }

    int stripCount(const SStyle& st, double length) {
        return std::max(1, (int)std::lround(length / st.period));
    }

    static void place(cairo_t* cr, cairo_surface_t* s, double x, double y, double w, double h) {
        if (w <= 0 || h <= 0)
            return;
        const double sw = cairo_image_surface_get_width(s), sh = cairo_image_surface_get_height(s);
        cairo_save(cr);
        cairo_translate(cr, x, y);
        cairo_scale(cr, w / sw, h / sh);
        cairo_set_source_surface(cr, s, 0, 0);
        cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_BILINEAR);
        cairo_paint(cr);
        cairo_restore(cr);
    }

    void composeCard(cairo_t* cr, const SStyle& st, double x, double y, double w, double h, uint32_t seed, bool flatInterior) {
        const double O = st.outset(), I = st.inset(), R = st.cornerReach(), K = st.cornerSize();
        const double s = st.scale;
        // the context is in device pixels; snap every tile edge to a pixel
        auto px = [&](double v) { return std::round(v * s); };

        if (flatInterior) {
            setColor(cr, st.paper | 0xff000000);
            cairo_rectangle(cr, px(x + I), px(y + I), px(x + w - I) - px(x + I), px(y + h - I) - px(y + I));
            cairo_fill(cr);
        }

        auto sides = [&](eSide side) {
            const bool   horizontal = side == SIDE_TOP || side == SIDE_BOTTOM;
            const double start = (horizontal ? x : y) + R, end = (horizontal ? x + w : y + h) - R;
            if (end - start < 1)
                return;
            const int n = stripCount(st, end - start);
            for (int i = 0; i < n; ++i) {
                const double a = px(start + (end - start) * i / n), b = px(start + (end - start) * (i + 1) / n);
                const int    v = variantFor(seed, side, i);
                double       bx, by, bw, bh;
                if (horizontal) {
                    bx = a, bw = b - a;
                    by = side == SIDE_TOP ? px(y - O) : px(y + h - I);
                    bh = side == SIDE_TOP ? px(y + I) - px(y - O) : px(y + h + O) - px(y + h - I);
                } else {
                    by = a, bh = b - a;
                    bx = side == SIDE_LEFT ? px(x - O) : px(x + w - I);
                    bw = side == SIDE_LEFT ? px(x + I) - px(x - O) : px(x + w + O) - px(x + w - I);
                }
                cairo_surface_t* t = strip(st, side, v);
                place(cr, t, bx, by, bw, bh);
                cairo_surface_destroy(t);
            }
        };
        sides(SIDE_TOP);
        sides(SIDE_BOTTOM);
        sides(SIDE_LEFT);
        sides(SIDE_RIGHT);

        const double cx[4] = {x - O, x + w - R, x - O, x + w - R};
        const double cy[4] = {y - O, y - O, y + h - R, y + h - R};
        for (int c = 0; c < 4; ++c) {
            cairo_surface_t* t = corner(st, (eCorner)c, variantFor(seed, SIDE_TOP, 1000 + c));
            place(cr, t, px(cx[c]), px(cy[c]), px(cx[c] + K) - px(cx[c]), px(cy[c] + K) - px(cy[c]));
            cairo_surface_destroy(t);
        }
    }
}
