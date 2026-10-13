#pragma once

// The deckle: a torn paper edge for windows, drawn as short repeating tiles.
//
// A window's card is cut from tiles that are drawn once and reused at any
// size: four corners, and edge strips that repeat along each side. Every
// strip starts and ends on the same straight baseline, so strips (and the
// three variants of each) join without a seam in any order, and a window can
// be resized freely without redrawing anything.
//
// Two sets of tiles make a card:
//   under the window  the shadow (down and to the right), the paper, the torn
//                     outline lit from the top left, chips bitten out of the
//                     edge with their pale torn fibres, worn corners;
//   over the window   the aged edge (a blotchy darkening that fades inward,
//                     strongest along the bottom and right), small tears,
//                     short wrinkles, and now and then a soft crease across a
//                     corner. These only reach the window's padding.
//
// This file only needs cairo, so the same code runs in the compositor plugin
// and in tools/deckle-preview.cpp.

#include <cairo/cairo.h>
#include <algorithm>
#include <cstdint>

namespace Deckle {

    // all lengths in logical pixels
    struct SStyle {
        double   scale      = 1.0;  // monitor scale; tiles are drawn at this resolution
        int      period     = 160;  // length of one edge strip
        int      margin     = 6;    // card edge sits this far outside the window
        double   amplitude  = 1.2;  // how far the torn edge wanders
        double   rimWidth   = 1.3;  // the outline
        double   shadowBlur = 4.5;  // shadow softness (box blur radius, three passes)
        double   shadowX    = 1.5;  // shadow offset: down and to the right
        double   shadowY    = 3.0;
        double   contactX   = 0.8;  // a tight second shadow right under the edge
        double   contactY   = 1.2;
        double   contact    = 1.0;  // its strength, relative to the shadow colour
        double   chips      = 1.0;  // how often the edge is chipped or torn (0 = never)
        double   creases    = 1.0;  // how often a corner is creased (0 = never)
        int      toneDepth  = 18;   // how far the aged edge reaches inward
        uint32_t paper      = 0xffd5d0ca; // ARGB, non-premultiplied
        uint32_t rimTop     = 0xffa09b94; // outline along the lit top edge
        uint32_t rimBottom  = 0xff57524d; // ... and the shaded bottom; the sides fall between
        uint32_t bevel      = 0x59ffffff; // light: the bevel, torn fibres, crease ridges
        uint32_t shadow     = 0x661e1d22; // shadow, tears, crease valleys
        uint32_t tone       = 0x30604c38; // the aged edge, at its darkest

        // band reaches this far outside the card edge (room for the shadow)
        int outset() const;
        // band reaches this far inside the card edge (one pixel under the window)
        int inset() const {
            return margin + 1;
        }
        // corner tiles cover this much of each edge, measured from the card corner
        int cornerReach() const {
            return std::max({inset() + 6, outset() + 4, toneDepth + 4});
        }
        // side of a corner tile
        int cornerSize() const {
            return outset() + cornerReach();
        }
        // the overlay band reaches from just outside the edge to toneDepth inside
        static constexpr int OVER_OUT = 2;
        // side of a crease tile
        static constexpr int CREASE = 100;
        bool operator==(const SStyle&) const = default;
    };

    enum eSide : uint8_t {
        SIDE_TOP = 0,
        SIDE_BOTTOM,
        SIDE_LEFT,
        SIDE_RIGHT,
    };

    enum eCorner : uint8_t {
        CORNER_TL = 0,
        CORNER_TR,
        CORNER_BL,
        CORNER_BR,
    };

    inline constexpr int VARIANTS = 3;

    // ---- under the window

    // Strip tile for one side, `period` long and outset() + inset() across.
    // Top and bottom strips run left to right; left and right strips run top
    // to bottom. Returns a premultiplied ARGB32 surface owned by the caller.
    cairo_surface_t* strip(const SStyle& style, eSide side, int variant);

    // Corner tile, cornerSize() square, with the card corner at outset() from
    // the outer sides.
    cairo_surface_t* corner(const SStyle& style, eCorner corner, int variant);

    // ---- over the window

    // Overlay strip, `period` long and OVER_OUT + toneDepth across, placed over
    // the matching strip (same side and variant): from OVER_OUT outside the card
    // edge to toneDepth inside it.
    cairo_surface_t* overlayStrip(const SStyle& style, eSide side, int variant);

    // Overlay corner, OVER_OUT + cornerReach() square, from OVER_OUT outside the
    // card corner.
    cairo_surface_t* overlayCorner(const SStyle& style, eCorner corner, int variant);

    // A crease across a corner, CREASE square, from the card corner inward.
    cairo_surface_t* crease(const SStyle& style, eCorner corner, int variant);

    // ---- layout, shared by the plugin and the preview

    // Which variant the i-th strip of a side uses, for a window seed.
    int variantFor(uint32_t seed, eSide side, int index);

    // How many strips of a side fit `length` (they are stretched slightly to fit).
    int stripCount(const SStyle& style, double length);

    // Which crease variant a window has at a corner, or -1 for none.
    int creaseFor(const SStyle& style, uint32_t seed, eCorner corner, double w, double h);

    // Draw a whole card into a cairo context in device pixels, at logical
    // position and size (the card's edge, not the window), by placing tiles
    // the way the plugin does. The preview tool draws composeCard, then the
    // window, then composeOverlay.
    void composeCard(cairo_t* cr, const SStyle& style, double x, double y, double w, double h, uint32_t seed, bool flatInterior = true);
    void composeOverlay(cairo_t* cr, const SStyle& style, double x, double y, double w, double h, uint32_t seed);
}
