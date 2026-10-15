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

    // ---------------------------------------------------------------- what happened to an edge

    // A chip is a bite out of the edge; a tear is a narrow notch with a slit
    // running inward from it; a wrinkle is a short ripple in from the edge.
    struct SMark {
        enum eKind : uint8_t {
            CHIP,
            TEAR,
            WRINKLE,
        } kind;
        double u;      // position along the side
        double width;  // of the bite
        double depth;  // of the bite
        double angle;  // of a slit or wrinkle, from the inward normal (radians)
        double length; // of a slit or wrinkle
    };

    static uint32_t stripSeed(eSide side, int variant) {
        return 7919U * (side + 1) + 104729U * (variant + 1);
    }

    static std::vector<SMark> marksFor(const SStyle& st, eSide side, int variant) {
        std::vector<SMark> marks;
        if (st.chips <= 0)
            return marks;

        const uint32_t seed = stripSeed(side, variant) ^ 0x51ed27U;
        const double   P    = st.period;
        // the bottom and right edges get handled, and knocked, the most
        const double   wear     = st.chips * (side == SIDE_BOTTOM || side == SIDE_RIGHT ? 1.25 : side == SIDE_TOP ? 0.7 : 0.9);
        const double   maxDepth = std::max(0.8, st.margin - 1.6);
        int            salt     = 0;
        auto           rnd      = [&] { return random01(seed, 77, (uint32_t)salt++); };

        auto           place = [&](SMark m) {
            // keep clear of the strip's ends and of each other
            if (m.u - m.width < 10 || m.u + m.width > P - 10)
                return;
            for (const auto& o : marks)
                if (std::abs(o.u - m.u) < o.width + m.width + 6)
                    return;
            marks.push_back(m);
        };

        const double r = rnd();
        const int    chips = r < 0.18 / wear ? 0 : r < 0.6 ? 1 : r < 0.9 ? 2 : 3;
        for (int i = 0; i < chips; ++i) {
            const double size = rnd();
            place({SMark::CHIP, 12 + rnd() * (P - 24), 4 + 10 * size, std::min(maxDepth, 1.3 + 3.2 * size + 0.5 * rnd()), 0, 0});
        }
        if (rnd() < 0.5 * wear)
            place({SMark::TEAR, 12 + rnd() * (P - 24), 2.2 + rnd(), std::min(maxDepth, 1.4 + rnd()), (rnd() - 0.5) * 0.9, 5 + 7 * rnd()});
        const int wrinkles = (int)(rnd() * 2.6 * st.chips);
        for (int i = 0; i < wrinkles; ++i)
            place({SMark::WRINKLE, 12 + rnd() * (P - 24), 1.0, 0, (rnd() - 0.5) * 0.8, 6 + 9 * rnd()});
        return marks;
    }

    // One edge's character along its length: how far it wanders (outward is
    // positive), how heavy and how dark the rim is, and where it is torn open
    // (fibre: 0 = cut surface, 1 = pale torn core). All return to the same
    // values at both ends, so any two edges can be joined end to end.
    struct SProfile {
        double              length = 0;
        double              step   = 0.5;
        std::vector<double> offset, width, alpha, fibre;

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
        double fibreAt(double u) const {
            return (u <= 0 || u >= length) ? 0 : sample(fibre, step, u);
        }
    };

    static SProfile makeProfile(const SStyle& st, double length, uint32_t seed, const std::vector<SMark>& marks = {}) {
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
            const double u     = k * p.step;
            double       off   = st.amplitude * (wander(u) - w0);
            double       fibre = 0;
            for (size_t m = 0; m < marks.size(); ++m) {
                const auto& mk = marks[m];
                if (mk.kind == SMark::WRINKLE)
                    continue;
                const double t = (u - mk.u) / (mk.width / 2);
                if (std::abs(t) < 1) {
                    // a ragged bite: deepest in the middle, its floor torn
                    const double jag = 0.7 + 0.3 * periodicNoise(u, length, 0.8, seed, 20 + (uint32_t)m);
                    off -= mk.depth * std::pow(1 - t * t, 0.7) * jag;
                }
                if (std::abs(t) < 1.25)
                    fibre = std::max(fibre, std::sqrt(std::max(0.0, 1 - std::abs(t) / 1.25)));
            }
            p.offset.push_back(off);
            p.width.push_back(st.rimWidth * std::clamp(0.9 + 0.4 * (heft(u) - h0), 0.45, 1.7));
            p.alpha.push_back(std::clamp(0.8 + 0.6 * (ink(u) - i0), 0.25, 1.0) * (1 - 0.8 * fibre));
            p.fibre.push_back(fibre);
        }
        return p;
    }

    // ---------------------------------------------------------------- helpers

    struct SPoint {
        double x, y;
    };

    static void setColor(cairo_t* cr, uint32_t argb, double alphaMul = 1.0) {
        cairo_set_source_rgba(cr, ((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0, (argb & 0xff) / 255.0,
                              std::clamp(((argb >> 24) & 0xff) / 255.0 * alphaMul, 0.0, 1.0));
    }

    static void addStop(cairo_pattern_t* pat, double at, uint32_t argb, double alphaMul) {
        cairo_pattern_add_color_stop_rgba(pat, at, ((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0, (argb & 0xff) / 255.0,
                                          std::clamp(((argb >> 24) & 0xff) / 255.0 * alphaMul, 0.0, 1.0));
    }

    static uint32_t blend(uint32_t a, uint32_t b, double t) {
        uint32_t out = 0;
        for (int c = 0; c < 32; c += 8)
            out |= (uint32_t)std::lround(((a >> c) & 0xff) * (1 - t) + ((b >> c) & 0xff) * t) << c;
        return out;
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
        return (int)std::ceil(3 * shadowBlur + std::max({std::abs(shadowX), std::abs(shadowY), std::abs(contactX), std::abs(contactY)}) + amplitude + rimWidth + 1);
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
            if (pad == 0)
                return surf;
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
        cairo_surface_t* tight = st.contact > 0 ? shadowMask(cv, shape, st.contactX, st.contactY, std::max(1, (int)std::lround(0.8 * st.scale))) : nullptr;
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
            const double a = (alphas[i - 1] + alphas[i]) / 2;
            if (a < 0.02)
                continue;
            cairo_new_path(cr);
            cairo_move_to(cr, pts[i - 1].x, pts[i - 1].y);
            cairo_line_to(cr, pts[i].x, pts[i].y);
            cairo_set_line_width(cr, (widths[i - 1] + widths[i]) / 2);
            setColor(cr, color, a);
            cairo_stroke(cr);
        }
    }

    // Where the edge is torn rather than cut, its core shows: a pale, soft
    // line with a few loose fibres standing out of it.
    static void tornCore(cairo_t* cr, const SStyle& st, const std::vector<SPoint>& pts, const std::vector<SPoint>& outward, const std::vector<double>& fibre,
                         uint32_t seed) {
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
        for (size_t i = 1; i < pts.size(); ++i) {
            const double f = (fibre[i - 1] + fibre[i]) / 2;
            if (f < 0.05)
                continue;
            cairo_new_path(cr);
            cairo_move_to(cr, pts[i - 1].x, pts[i - 1].y);
            cairo_line_to(cr, pts[i].x, pts[i].y);
            cairo_set_line_width(cr, 1.2);
            setColor(cr, st.bevel, 1.4 * f);
            cairo_stroke(cr);

            // a fibre every few samples
            if (f > 0.35 && random01(seed, 31, (uint32_t)i) < 0.22) {
                const double len = 0.6 + 1.6 * random01(seed, 32, (uint32_t)i);
                const double tilt = (random01(seed, 33, (uint32_t)i) - 0.5) * 1.2;
                const auto   o    = outward[i];
                cairo_new_path(cr);
                cairo_move_to(cr, pts[i].x, pts[i].y);
                cairo_line_to(cr, pts[i].x + (o.x - o.y * tilt) * len, pts[i].y + (o.y + o.x * tilt) * len);
                cairo_set_line_width(cr, 0.45);
                setColor(cr, st.bevel, 1.8 * f);
                cairo_stroke(cr);
            }
        }
    }

    // Light falls from the top left: the top edge is palest, the left a
    // little darker, the right darker still, the bottom darkest.
    static uint32_t rimColor(const SStyle& st, eSide side) {
        switch (side) {
            case SIDE_TOP: return st.rimTop;
            case SIDE_BOTTOM: return st.rimBottom;
            case SIDE_LEFT: return blend(st.rimTop, st.rimBottom, 0.3);
            default: return blend(st.rimTop, st.rimBottom, 0.8);
        }
    }

    static double bevelStrength(eSide side) {
        switch (side) {
            case SIDE_TOP: return 0.75;
            case SIDE_LEFT: return 0.35;
            default: return 0.0;
        }
    }

    // how strongly each edge has aged
    static double toneStrength(eSide side) {
        switch (side) {
            case SIDE_BOTTOM: return 1.0;
            case SIDE_RIGHT: return 0.85;
            case SIDE_LEFT: return 0.5;
            default: return 0.4;
        }
    }

    // ---------------------------------------------------------------- strips

    cairo_surface_t* strip(const SStyle& st, eSide side, int variant) {
        const double             P = st.period, O = st.outset(), I = st.inset();
        const double             B = O + 2; // blur room past the tile's ends
        const bool               horizontal = side == SIDE_TOP || side == SIDE_BOTTOM;
        const uint32_t           seed       = stripSeed(side, variant);
        const std::vector<SMark> marks      = marksFor(st, side, variant);
        const SProfile           prof       = makeProfile(st, P, seed, marks);

        // (u along the side, n inward from the card edge) -> tile coordinates
        auto map = [&](double u, double n) -> SPoint {
            switch (side) {
                case SIDE_TOP: return {u, O + n};
                case SIDE_BOTTOM: return {u, I - n};
                case SIDE_LEFT: return {O + n, u};
                default: return {I - n, u};
            }
        };
        SPoint out;
        {
            const SPoint a = map(0, 0), b = map(0, -1);
            out            = {b.x - a.x, b.y - a.y};
        }

        SCanvas             cv(st, horizontal ? P : O + I, horizontal ? O + I : P, (int)std::ceil(B));
        cairo_t*            cr = cv.cr;

        std::vector<SPoint> edge, inner, shape, outward;
        std::vector<double> widths, alphas, fibres;
        for (double u = -B; u <= P + B + 1e-6; u += prof.step) {
            const double off = prof.offsetAt(u);
            edge.push_back(map(u, -off));
            widths.push_back(prof.widthAt(u));
            alphas.push_back(prof.alphaAt(u));
            fibres.push_back(prof.fibreAt(u));
            outward.push_back(out);
            inner.push_back(map(u, -off + prof.widthAt(u) / 2 + 1.0));
        }
        shape = edge;
        shape.push_back(map(P + B, I + B));
        shape.push_back(map(-B, I + B));

        shadowAndPaper(cv, st, shape);
        bevel(cr, st, inner, shape, bevelStrength(side));
        rim(cr, edge, widths, alphas, rimColor(st, side));
        tornCore(cr, st, edge, outward, fibres, seed);

        return cv.crop();
    }

    // ---------------------------------------------------------------- corners

    // how much a corner has been worn or torn off
    static double cornerWear(const SStyle& st, eCorner which, int variant) {
        const double r = random01(91U * (which + 1), 17U * (variant + 1), 5);
        return 0.6 + std::min(st.margin - 1.5, 4.2 * r * r * r * std::max(st.chips, 0.0));
    }

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

        const double        wear = cornerWear(st, which, variant);
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
        const size_t split = edge.size() - 1;
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

        const eSide hside = bottom ? SIDE_BOTTOM : SIDE_TOP;
        const eSide vside = right ? SIDE_RIGHT : SIDE_LEFT;
        shadowAndPaper(cv, st, shape);
        bevel(cr, st, innerH, shape, bevelStrength(hside));
        bevel(cr, st, innerV, shape, bevelStrength(vside));
        rim(cr, std::vector<SPoint>(edge.begin(), edge.begin() + split + 1), std::vector<double>(widths.begin(), widths.begin() + split + 1),
            std::vector<double>(alphas.begin(), alphas.begin() + split + 1), rimColor(st, vside));
        rim(cr, std::vector<SPoint>(edge.begin() + split, edge.end()), std::vector<double>(widths.begin() + split, widths.end()),
            std::vector<double>(alphas.begin() + split, alphas.end()), rimColor(st, hside));

        // a worn corner shows its torn core along the cut
        if (wear > 1.2) {
            cairo_new_path(cr);
            const SPoint a = edge[split], b = edge[split + 1];
            cairo_move_to(cr, a.x, a.y);
            cairo_line_to(cr, b.x, b.y);
            cairo_set_line_width(cr, 1.2);
            cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
            setColor(cr, st.bevel, 1.8);
            cairo_stroke(cr);
        }

        return cv.crop();
    }

    // ---------------------------------------------------------------- over the window

    // the aged edge: a band that darkens toward the edge, blotchy along it
    static void toneBand(cairo_t* cr, const SStyle& st, double strength, SPoint from, SPoint to) {
        if (strength <= 0)
            return;
        cairo_pattern_t* pat = cairo_pattern_create_linear(from.x, from.y, to.x, to.y);
        // eased: dark right at the edge, gone by toneDepth
        for (int i = 0; i <= 6; ++i) {
            const double t = i / 6.0;
            addStop(pat, t, st.tone, strength * std::pow(1 - t, 1.5));
        }
        cairo_set_source(cr, pat);
        cairo_pattern_destroy(pat);
    }

    // A fold or ripple in the paper, from a to b bowing toward ctl: a broad
    // soft valley on the shaded side, a faint broken crease line, and a lit
    // ridge on the side facing the light (up and left). Its ends fade out, so
    // it rises out of the paper rather than being drawn on it.
    static void fold(cairo_t* cr, const SStyle& st, SPoint a, SPoint ctl, SPoint b, double strength, uint32_t seed) {
        const double dx = b.x - a.x, dy = b.y - a.y, len = std::max(1e-6, std::hypot(dx, dy));
        SPoint       nrm = {-dy / len, dx / len};
        if (nrm.x + nrm.y > 0)
            nrm = {-nrm.x, -nrm.y}; // toward the light

        // the fold's path, a little unsteady
        const int           n = std::max(8, (int)(len / 1.5));
        std::vector<SPoint> pts;
        std::vector<double> env, ink;
        for (int i = 0; i <= n; ++i) {
            const double t = (double)i / n;
            const double u = 1 - t;
            SPoint       p = {u * u * a.x + 2 * u * t * ctl.x + t * t * b.x, u * u * a.y + 2 * u * t * ctl.y + t * t * b.y};
            const double j = 0.7 * periodicNoise(t * len, len * 4, 9, seed, 60);
            pts.push_back({p.x + nrm.x * j, p.y + nrm.y * j});
            env.push_back(std::pow(std::sin(t * 3.14159265), 0.6));
            ink.push_back(std::clamp(0.6 + 0.6 * periodicNoise(t * len, len * 4, 3, seed, 61), 0.1, 1.0));
        }

        const double shadowA = std::max(0.05, ((st.shadow >> 24) & 0xff) / 255.0);
        auto         layer   = [&](double offset, double width, uint32_t color, double alpha, bool broken) {
            cairo_set_line_cap(cr, CAIRO_LINE_CAP_BUTT);
            cairo_set_line_width(cr, width);
            for (int i = 1; i <= n; ++i) {
                const double e = (env[i - 1] + env[i]) / 2 * (broken ? (ink[i - 1] + ink[i]) / 2 : 1);
                if (e * alpha < 0.004)
                    continue;
                cairo_new_path(cr);
                cairo_move_to(cr, pts[i - 1].x + nrm.x * offset, pts[i - 1].y + nrm.y * offset);
                cairo_line_to(cr, pts[i].x + nrm.x * offset, pts[i].y + nrm.y * offset);
                setColor(cr, color, alpha * e);
                cairo_stroke(cr);
            }
        };
        layer(-2.2, 4.5, st.shadow, 0.045 * strength / shadowA, false); // the valley's shade
        layer(-0.8, 1.8, st.shadow, 0.07 * strength / shadowA, false);
        layer(0.0, 0.7, st.shadow, 0.16 * strength / shadowA, true);   // the crease itself
        layer(1.3, 2.2, st.bevel, 0.9 * strength, false);              // the ridge in the light
    }

    cairo_surface_t* overlayStrip(const SStyle& st, eSide side, int variant) {
        const double             P = st.period, D = st.toneDepth, E = SStyle::OVER_OUT;
        const bool               horizontal = side == SIDE_TOP || side == SIDE_BOTTOM;
        const uint32_t           seed       = stripSeed(side, variant);
        const std::vector<SMark> marks      = marksFor(st, side, variant);
        const SProfile           prof       = makeProfile(st, P, seed, marks);

        auto                     map = [&](double u, double n) -> SPoint {
            switch (side) {
                case SIDE_TOP: return {u, E + n};
                case SIDE_BOTTOM: return {u, D - n};
                case SIDE_LEFT: return {E + n, u};
                default: return {D - n, u};
            }
        };

        SCanvas  cv(st, horizontal ? P : E + D, horizontal ? E + D : P, 0);
        cairo_t* cr = cv.cr;

        // only on the paper
        std::vector<SPoint> shape;
        for (double u = 0; u <= P + 1e-6; u += prof.step)
            shape.push_back(map(u, -prof.offsetAt(u)));
        shape.push_back(map(P, D + 1));
        shape.push_back(map(0, D + 1));
        polygon(cr, shape);
        cairo_clip(cr);

        // the aged edge, in slices so its strength can wander along the side
        if (((st.tone >> 24) & 0xff) > 0) {
            auto         blotch = [&](double u) { return 0.55 * periodicNoise(u, P, 26, seed, 40) + 0.3 * periodicNoise(u, P, 7, seed, 41); };
            const double b0     = blotch(0);
            const double slice  = 2.0;
            for (double u = 0; u < P; u += slice) {
                const double m = std::clamp(1 + 0.9 * (blotch(u + slice / 2) - b0), 0.25, 2.0);
                cairo_save(cr);
                const SPoint p0 = map(u, -E), p1 = map(u + slice + 0.05, D);
                cairo_rectangle(cr, std::min(p0.x, p1.x), std::min(p0.y, p1.y), std::abs(p1.x - p0.x), std::abs(p1.y - p0.y));
                cairo_clip(cr);
                toneBand(cr, st, toneStrength(side) * m, map(u, 0), map(u, D));
                cairo_paint(cr);
                cairo_restore(cr);
            }
        }

        for (size_t i = 0; i < marks.size(); ++i) {
            const auto& mk = marks[i];
            if (mk.kind == SMark::TEAR) {
                // a slit from the bottom of the notch inward, its far lip catching the light
                const double edgeN = -prof.offsetAt(mk.u);
                const SPoint a     = map(mk.u, edgeN + 0.2);
                const SPoint b     = map(mk.u + std::sin(mk.angle) * mk.length, edgeN + std::cos(mk.angle) * mk.length);
                const SPoint c     = map(mk.u + std::sin(mk.angle) * mk.length * 0.5 + 0.4, edgeN + std::cos(mk.angle) * mk.length * 0.5);
                cairo_new_path(cr);
                cairo_move_to(cr, a.x, a.y);
                cairo_curve_to(cr, c.x, c.y, c.x, c.y, b.x, b.y);
                cairo_set_line_width(cr, 0.9);
                cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
                setColor(cr, rimColor(st, SIDE_BOTTOM), 0.85);
                cairo_stroke(cr);
                const SPoint a2 = map(mk.u + 0.8, edgeN + 0.4), b2 = map(mk.u + std::sin(mk.angle) * mk.length * 0.8 + 0.7, edgeN + std::cos(mk.angle) * mk.length * 0.8);
                cairo_new_path(cr);
                cairo_move_to(cr, a2.x, a2.y);
                cairo_line_to(cr, b2.x, b2.y);
                cairo_set_line_width(cr, 0.7);
                setColor(cr, st.bevel, 1.4);
                cairo_stroke(cr);
            } else if (mk.kind == SMark::WRINKLE) {
                const double edgeN = -prof.offsetAt(mk.u);
                const SPoint a     = map(mk.u, edgeN + 0.3);
                const SPoint b     = map(mk.u + std::sin(mk.angle) * mk.length, edgeN + std::cos(mk.angle) * mk.length);
                const SPoint c     = map(mk.u + std::sin(mk.angle) * mk.length * 0.5 + 0.8, edgeN + std::cos(mk.angle) * mk.length * 0.5);
                fold(cr, st, a, c, b, 0.8, seed + 100 * (uint32_t)i);
            }
        }

        return cv.crop();
    }

    cairo_surface_t* overlayCorner(const SStyle& st, eCorner which, int variant) {
        const double   E = SStyle::OVER_OUT, R = st.cornerReach(), D = st.toneDepth;
        const double   K      = E + R;
        const bool     right  = which == CORNER_TR || which == CORNER_BR;
        const bool     bottom = which == CORNER_BL || which == CORNER_BR;
        const SProfile horiz  = makeProfile(st, R, 31337U * (which + 1) + 7U * (variant + 1));
        const SProfile vert   = makeProfile(st, R, 92821U * (which + 1) + 13U * (variant + 1));
        const double   wear   = cornerWear(st, which, variant);

        // top-left orientation, the card corner at (E, E)
        auto     map = [&](double x, double y) -> SPoint { return {right ? K - x : x, bottom ? K - y : y}; };

        SCanvas  cv(st, K, K, 0);
        cairo_t* cr = cv.cr;

        std::vector<SPoint> shape;
        for (double v = R; v >= wear - 1e-6; v -= vert.step)
            shape.push_back(map(E - vert.offsetAt(v), E + v));
        for (double u = wear; u <= R + 1e-6; u += horiz.step)
            shape.push_back(map(E + u, E - horiz.offsetAt(u)));
        shape.push_back(map(K, K));
        polygon(cr, shape);
        cairo_clip(cr);

        if (((st.tone >> 24) & 0xff) > 0) {
            // both edges age into the corner, which ends up darkest
            toneBand(cr, st, toneStrength(bottom ? SIDE_BOTTOM : SIDE_TOP), map(E, E), map(E, E + D));
            cairo_paint(cr);
            toneBand(cr, st, toneStrength(right ? SIDE_RIGHT : SIDE_LEFT), map(E, E), map(E + D, E));
            cairo_paint(cr);
        }
        return cv.crop();
    }

    cairo_surface_t* crease(const SStyle& st, eCorner which, int variant) {
        const double C      = SStyle::CREASE;
        const bool   right  = which == CORNER_TR || which == CORNER_BR;
        const bool   bottom = which == CORNER_BL || which == CORNER_BR;
        auto         map    = [&](double x, double y) -> SPoint { return {right ? C - x : x, bottom ? C - y : y}; };
        const uint32_t seed = 6151U * (which + 1) + 3079U * (variant + 1);
        auto           rnd  = [&](int k) { return random01(seed, 55, (uint32_t)k); };

        SCanvas  cv(st, C, C, 0);
        cairo_t* cr = cv.cr;

        // a fold across the corner, from the top edge to the side edge
        const double ax = 42 + 46 * rnd(1), by = 42 + 46 * rnd(2);
        const SPoint a = map(ax, -1), b = map(-1, by);
        const double bow = (rnd(3) - 0.5) * 18;
        const SPoint mid = map(ax / 2 + bow * 0.7, by / 2 + bow * 0.7);
        fold(cr, st, a, mid, b, std::min(1.0, st.creases), seed);

        // and a smaller ripple or two branching off it
        const int branches = 1 + (int)(rnd(4) * 2);
        for (int i = 0; i < branches; ++i) {
            const double t  = 0.25 + 0.5 * rnd(10 + i);
            const double sx = ax * (1 - t), sy = by * t;
            const double ang = (rnd(20 + i) - 0.5) * 1.4;
            const double len = 9 + 12 * rnd(30 + i);
            // roughly away from the corner
            const double dx = std::cos(0.785 + ang) * len, dy = std::sin(0.785 + ang) * len;
            fold(cr, st, map(sx, sy), map(sx + dx * 0.5 + 1, sy + dy * 0.5), map(sx + dx, sy + dy), 0.6 * std::min(1.0, st.creases), seed + 7 * (uint32_t)i);
        }
        return cv.crop();
    }

    // ---------------------------------------------------------------- paper grain

    // value noise on a square lattice of `cells` x `cells`, repeating
    static double tileNoise(double x, double y, int cells, double cell, uint32_t salt) {
        const double tx = x / cell, ty = y / cell;
        const int    ix = (int)std::floor(tx), iy = (int)std::floor(ty);
        double       fx = tx - ix, fy = ty - iy;
        fx     = fx * fx * (3 - 2 * fx);
        fy     = fy * fy * (3 - 2 * fy);
        auto v = [&](int i, int j) {
            i = ((i % cells) + cells) % cells;
            j = ((j % cells) + cells) % cells;
            return random01(salt, (uint32_t)i, (uint32_t)j);
        };
        return (v(ix, iy) * (1 - fx) + v(ix + 1, iy) * fx) * (1 - fy) + (v(ix, iy + 1) * (1 - fx) + v(ix + 1, iy + 1) * fx) * fy;
    }

    cairo_surface_t* grainTile(int size, double strength) {
        // Paper, looked at closely: a fine tooth, faint small-scale cloudiness
        // (the pulp settling unevenly), short fibres lying mostly one way,
        // some darker and some catching the light, and the odd inclusion.
        // Each pixel lightens (white) or darkens (black) the window a little.
        size              = std::max(64, size / 64 * 64);
        strength          = std::clamp(strength, 0.0, 3.0);
        auto*        s    = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
        const int    rows = cairo_image_surface_get_stride(s) / 4;
        cairo_surface_flush(s);
        auto* px = reinterpret_cast<uint32_t*>(cairo_image_surface_get_data(s));

        for (int y = 0; y < size; ++y) {
            for (int x = 0; x < size; ++x) {
                // formation: small flocs over a very gentle larger swell
                const double cloud = tileNoise(x, y, size / 4, 4, 21) * 0.55 + tileNoise(x, y, size / 8, 8, 22) * 0.30 + tileNoise(x, y, size / 32, 32, 23) * 0.15;
                // tooth: per-pixel, softened with its neighbour along the grain
                const double tooth = 0.6 * random01(24, (uint32_t)x, (uint32_t)y) + 0.4 * random01(24, (uint32_t)((x + 1) % size), (uint32_t)y);
                const bool   speck = random01(25, (uint32_t)(x / 2), (uint32_t)(y / 2)) > 0.99985;
                const double g     = ((cloud - 0.5) * 0.040 + (tooth - 0.5) * 0.045) * strength - (speck ? 0.10 : 0.0) * std::min(1.0, strength) - 0.006 * strength;
                uint32_t     v     = 0;
                if (g < 0) {
                    const double a = std::clamp(-g, 0.0, 0.45);
                    v              = (uint32_t)std::lround(a * 255) << 24; // black, premultiplied
                } else {
                    const double a = std::clamp(g * 0.8, 0.0, 0.30);
                    const auto   c = (uint32_t)std::lround(a * 255);
                    v              = (c << 24) | (c << 16) | (c << 8) | c; // white, premultiplied
                }
                px[y * rows + x] = v;
            }
        }
        cairo_surface_mark_dirty(s);

        // fibres, drawn on the torus so the tile still repeats: mostly along
        // one direction (the way the paper ran through the machine)
        cairo_t* cr = cairo_create(s);
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
        const int fibres = size * size / 900;
        for (int i = 0; i < fibres; ++i) {
            const bool   light = random01(26, i, 5) < 0.55;
            const double x0 = random01(26, i, 0) * size, y0 = random01(26, i, 1) * size;
            const double ang  = (random01(26, i, 2) - 0.5) * (random01(26, i, 6) < 0.8 ? 1.1 : 3.14159265358979);
            const double len  = 3 + 11 * random01(26, i, 3) * random01(26, i, 7);
            const double bend = (random01(26, i, 4) - 0.5) * len * 0.5;
            const double dx = std::cos(ang) * len, dy = std::sin(ang) * len;
            cairo_set_line_width(cr, 0.45 + 0.4 * random01(26, i, 8));
            if (light)
                cairo_set_source_rgba(cr, 1, 1, 1, std::min(1.0, (0.05 + 0.05 * random01(26, i, 9)) * strength));
            else
                cairo_set_source_rgba(cr, 0, 0, 0, std::min(1.0, (0.025 + 0.03 * random01(26, i, 9)) * strength));
            for (int ox = -1; ox <= 1; ++ox) {
                for (int oy = -1; oy <= 1; ++oy) {
                    const double bx = x0 + ox * size, by = y0 + oy * size;
                    cairo_move_to(cr, bx, by);
                    cairo_curve_to(cr, bx + dx * 0.3 - dy / len * bend, by + dy * 0.3 + dx / len * bend, bx + dx * 0.7 - dy / len * bend, by + dy * 0.7 + dx / len * bend, bx + dx,
                                   by + dy);
                    cairo_stroke(cr);
                }
            }
        }
        cairo_destroy(cr);
        return s;
    }

    // ---------------------------------------------------------------- layout

    int variantFor(uint32_t seed, eSide side, int index) {
        // the modulo on the unsigned hash: cast first and half the hashes go
        // negative, and a negative variant indexes outside the tile arrays
        return (int)((mix(seed * 4U + side + 1U) ^ mix((uint32_t)index * 0x27d4eb2dU + 3U)) % (uint32_t)VARIANTS);
    }

    int stripCount(const SStyle& st, double length) {
        return std::max(1, (int)std::lround(length / st.period));
    }

    int creaseFor(const SStyle& st, uint32_t seed, eCorner corner, double w, double h) {
        if (st.creases <= 0 || w < 2.2 * SStyle::CREASE || h < 2.2 * SStyle::CREASE)
            return -1;
        // the lower corners, handled most, crease most
        static constexpr double CHANCE[4] = {0.12, 0.3, 0.45, 0.5};
        auto creased = [&](int c) { return random01(seed, 101, c) < CHANCE[c] * st.creases; };
        if (!creased(corner))
            return -1;
        // two creased corners at most
        int before = 0;
        for (int c = 0; c < corner; ++c)
            before += creased(c);
        if (before >= 2)
            return -1;
        return (int)(random01(seed, 102, corner) * VARIANTS) % VARIANTS;
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

    // run `fn(side, index, variant, a0, a1)` for every strip around a card
    template <typename F>
    static void forEachStrip(const SStyle& st, double x, double y, double w, double h, uint32_t seed, F fn) {
        const double R = st.cornerReach();
        for (int s = 0; s < 4; ++s) {
            const eSide  side       = (eSide)s;
            const bool   horizontal = side == SIDE_TOP || side == SIDE_BOTTOM;
            const double start = (horizontal ? x : y) + R, end = (horizontal ? x + w : y + h) - R;
            if (end - start < 1)
                continue;
            const int n = stripCount(st, end - start);
            for (int i = 0; i < n; ++i)
                fn(side, variantFor(seed, side, i), start + (end - start) * i / n, start + (end - start) * (i + 1) / n);
        }
    }

    void composeCard(cairo_t* cr, const SStyle& st, double x, double y, double w, double h, uint32_t seed, bool flatInterior) {
        const double O = st.outset(), I = st.inset(), R = st.cornerReach(), K = st.cornerSize();
        const double s  = st.scale;
        auto         px = [&](double v) { return std::round(v * s); };

        if (flatInterior) {
            setColor(cr, st.paper | 0xff000000);
            cairo_rectangle(cr, px(x + I), px(y + I), px(x + w - I) - px(x + I), px(y + h - I) - px(y + I));
            cairo_fill(cr);
        }

        forEachStrip(st, x, y, w, h, seed, [&](eSide side, int v, double a0, double a1) {
            double x0, y0, x1, y1;
            switch (side) {
                case SIDE_TOP: x0 = a0, x1 = a1, y0 = y - O, y1 = y + I; break;
                case SIDE_BOTTOM: x0 = a0, x1 = a1, y0 = y + h - I, y1 = y + h + O; break;
                case SIDE_LEFT: y0 = a0, y1 = a1, x0 = x - O, x1 = x + I; break;
                default: y0 = a0, y1 = a1, x0 = x + w - I, x1 = x + w + O; break;
            }
            cairo_surface_t* t = strip(st, side, v);
            place(cr, t, px(x0), px(y0), px(x1) - px(x0), px(y1) - px(y0));
            cairo_surface_destroy(t);
        });

        const double cx[4] = {x - O, x + w - R, x - O, x + w - R};
        const double cy[4] = {y - O, y - O, y + h - R, y + h - R};
        for (int c = 0; c < 4; ++c) {
            cairo_surface_t* t = corner(st, (eCorner)c, variantFor(seed, SIDE_TOP, 1000 + c));
            place(cr, t, px(cx[c]), px(cy[c]), px(cx[c] + K) - px(cx[c]), px(cy[c] + K) - px(cy[c]));
            cairo_surface_destroy(t);
        }
    }

    void composeOverlay(cairo_t* cr, const SStyle& st, double x, double y, double w, double h, uint32_t seed) {
        const double E = SStyle::OVER_OUT, D = st.toneDepth, R = st.cornerReach(), C = SStyle::CREASE;
        const double s  = st.scale;
        auto         px = [&](double v) { return std::round(v * s); };

        forEachStrip(st, x, y, w, h, seed, [&](eSide side, int v, double a0, double a1) {
            double x0, y0, x1, y1;
            switch (side) {
                case SIDE_TOP: x0 = a0, x1 = a1, y0 = y - E, y1 = y + D; break;
                case SIDE_BOTTOM: x0 = a0, x1 = a1, y0 = y + h - D, y1 = y + h + E; break;
                case SIDE_LEFT: y0 = a0, y1 = a1, x0 = x - E, x1 = x + D; break;
                default: y0 = a0, y1 = a1, x0 = x + w - D, x1 = x + w + E; break;
            }
            cairo_surface_t* t = overlayStrip(st, side, v);
            place(cr, t, px(x0), px(y0), px(x1) - px(x0), px(y1) - px(y0));
            cairo_surface_destroy(t);
        });

        const double cx[4] = {x - E, x + w - R, x - E, x + w - R};
        const double cy[4] = {y - E, y - E, y + h - R, y + h - R};
        for (int c = 0; c < 4; ++c) {
            cairo_surface_t* t = overlayCorner(st, (eCorner)c, variantFor(seed, SIDE_TOP, 1000 + c));
            place(cr, t, px(cx[c]), px(cy[c]), px(cx[c] + E + R) - px(cx[c]), px(cy[c] + E + R) - px(cy[c]));
            cairo_surface_destroy(t);

            const int v = creaseFor(st, seed, (eCorner)c, w, h);
            if (v < 0)
                continue;
            const double kx = (c == CORNER_TR || c == CORNER_BR) ? x + w - C : x;
            const double ky = (c == CORNER_BL || c == CORNER_BR) ? y + h - C : y;
            t               = crease(st, (eCorner)c, v);
            place(cr, t, px(kx), px(ky), px(kx + C) - px(kx), px(ky + C) - px(ky));
            cairo_surface_destroy(t);
        }
    }
}
