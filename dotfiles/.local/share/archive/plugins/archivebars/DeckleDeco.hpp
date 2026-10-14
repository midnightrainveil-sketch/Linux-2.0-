#pragma once

// The window's paper edge, as two Hyprland decorations, and the paper grain
// over the windows that want it.
//
// Every window becomes a card a few pixels larger than itself. Under the
// window: the card's shadow, paper and torn, chipped edge. Over the window
// (only its padding): the aged edge, tears, wrinkles and creases. Both are
// laid out of the tiles in deckle.cpp around the window and its title bar.
// The window's own background is the same paper colour, so its straight edge
// disappears and only the torn one shows. Tiles are drawn once per look
// (colours, monitor scale, focus) and reused, so resizing costs nothing.
//
// Grain: the layer over the window also lays one seamless grain tile over
// the whole card. Which windows get it comes from the window rule effect
// archivebars:grain (the config gives it to terminals and system tools),
// else plugin:archivebars:grain_default; a click on the bar's grain glyph,
// or hl.plugin.archivebars.toggle_grain(), flips it for one window.

#define WLR_USE_UNSTABLE

#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include "deckle.hpp"

class CArchiveDeckle : public IHyprWindowDecoration {
  public:
    // over = false: the card under the window; true: the marks over it
    CArchiveDeckle(PHLWINDOW, bool over);
    virtual ~CArchiveDeckle();

    virtual SDecorationPositioningInfo getPositioningInfo();
    virtual void                       onPositioningReply(const SDecorationPositioningReply& reply);
    virtual void                       draw(PHLMONITOR, float const& a);
    virtual eDecorationType            getDecorationType();
    virtual void                       updateWindow(PHLWINDOW);
    virtual void                       damageEntire();
    virtual eDecorationLayer           getDecorationLayer();
    virtual uint64_t                   getDecorationFlags();
    virtual std::string                getDisplayName();

    PHLWINDOW                          getOwner();
    void                               updateRules();

    // grain over this window (the layer over the window keeps the state)
    bool                               grainOn();
    void                               toggleGrain();
    bool                               isOver() const {
        return m_over;
    }

    WP<CArchiveDeckle>                 m_self;

  private:
    PHLWINDOWREF m_window;
    bool         m_over = false;
    SBoxExtents  m_extents;
    SBoxExtents  m_reportedExtents;
    bool         m_hidden = false;
    uint32_t     m_seed   = 0;
    // from the rules (nullopt: no rule says), and a click's override
    std::optional<bool> m_grainRule;
    std::optional<bool> m_grainOverride;

    bool         grainWanted(); // ignoring the global strength

    bool         visible();
    // the card's edge (window, title bar and margin), in global logical
    // coordinates, following the workspace slide and floating offset
    CBox   cardBox();
    double reach(); // how far this layer draws outside the card edge
    void   updateExtents();
    void   renderPass(PHLMONITOR, float const& a);
    void   renderUnder(PHLMONITOR, float const& a, const CBox& card);
    void   renderOver(PHLMONITOR, float const& a, const CBox& card);

    friend class CDecklePassElement;
};

class CDecklePassElement : public IPassElement {
  public:
    struct SData {
        // weak: a window (and its decoration) can go between the pass being
        // built and drawn
        WP<CArchiveDeckle> deco;
        float              a = 1.F;
    };

    CDecklePassElement(const SData& data);
    virtual ~CDecklePassElement() = default;

    virtual std::vector<UP<IPassElement>> draw() override;
    virtual bool                          needsLiveBlur() override;
    virtual bool                          needsPrecomputeBlur() override;
    virtual std::optional<CBox>           boundingBox() override;

    virtual const char*                   passName() override {
        return "CDecklePassElement";
    }

    virtual ePassElementType type() override {
        return EK_CUSTOM;
    }

  private:
    SData m_data;
};

// wiring, called from main.cpp
void deckleInit(HANDLE handle);
void deckleOnNewWindow(PHLWINDOW window);
void deckleOnUpdateRules(PHLWINDOW window);
void deckleExit();

// for the title bar's grain glyph
bool deckleGrainOn(PHLWINDOW window);
void deckleToggleGrain(PHLWINDOW window);
