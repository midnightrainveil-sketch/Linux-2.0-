#pragma once

// The deckle: a torn paper edge for windows, drawn as short repeating tiles.
//
// A window's card is cut from tiles that are drawn once and reused at any
// size: four corners, and edge strips that repeat along each side. Every
// strip starts and ends on the same straight baseline, so strips (and the
// three variants of each) join without a seam in any order, and a window can
// be resized freely without redrawing anything. Each tile carries its own
// soft shadow, the paper fill, a light bevel and the ragged rim.
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
        int      margin     = 4;    // card edge sits this far outside the window
        double   amplitude  = 1.2;  // how far the torn edge wanders
        double   rimWidth   = 1.3;  // the outline
        double   shadowBlur = 4.0;  // shadow softness (box blur radius, three passes)
        double   shadowX    = -0.5; // shadow offset
        double   shadowY    = 2.5;
        double   contactY   = 1.0;  // a tight second shadow right under the edge
        double   contact    = 1.0;  // its strength, relative to the shadow colour
        uint32_t paper      = 0xffd5d0ca; // ARGB, non-premultiplied
        uint32_t rimTop     = 0xffa09b94;
        uint32_t rimBottom  = 0xff57524d;
        uint32_t bevel      = 0x59ffffff; // the light line just inside the rim
        uint32_t shadow     = 0x661e1d22;

        // band reaches this far outside the card edge (room for the shadow)
        int outset() const;
        // band reaches this far inside the card edge (one pixel under the window)
        int inset() const {
            return margin + 1;
        }
        // corner tiles cover this much of each edge, measured from the card corner
        int cornerReach() const {
            return std::max(inset() + 6, outset() + 4);
        }
        // side of a corner tile
        int cornerSize() const {
            return outset() + cornerReach();
        }
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

    // Strip tile for one side, `period` long and outset() + inset() across.
    // Top and bottom strips run left to right; left and right strips run top
    // to bottom. The top edge is ruled in rimTop (it catches the light), the
    // bottom in rimBottom, the sides halfway between.
    // Returns a premultiplied ARGB32 surface owned by the caller.
    cairo_surface_t* strip(const SStyle& style, eSide side, int variant);

    // Corner tile, cornerSize() square, with the card corner at outset() from
    // the outer sides.
    cairo_surface_t* corner(const SStyle& style, eCorner corner, int variant);

    // Draw a whole card into a cairo context at logical size w x h (the card's
    // edge, not the window), by placing tiles the same way the plugin does.
    // Used by the preview tool; `seed` picks the variant sequence.
    void composeCard(cairo_t* cr, const SStyle& style, double x, double y, double w, double h, uint32_t seed, bool flatInterior = true);

    // Which variant the i-th strip of a side uses, for a window seed.
    int variantFor(uint32_t seed, eSide side, int index);

    // How many strips of a side fit `length` (they are stretched slightly to fit).
    int stripCount(const SStyle& style, double length);
}
