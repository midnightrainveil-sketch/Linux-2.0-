#pragma once

// The window's paper edge, as two Hyprland decorations.
//
// Every window becomes a card a few pixels larger than itself. Under the
// window: the card's shadow, paper and torn, chipped edge. Over the window
// (only its padding): the aged edge, tears, wrinkles and creases. Both are
// laid out of the tiles in deckle.cpp around the window and its title bar.
// The window's own background is the same paper colour, so its straight edge
// disappears and only the torn one shows. Tiles are drawn once per look
// (colours, monitor scale, focus) and reused, so resizing costs nothing.

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

    WP<CArchiveDeckle>                 m_self;

  private:
    PHLWINDOWREF m_window;
    bool         m_over = false;
    SBoxExtents  m_extents;
    SBoxExtents  m_reportedExtents;
    bool         m_hidden = false;
    uint32_t     m_seed   = 0;

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
        CArchiveDeckle* deco = nullptr;
        float           a    = 1.F;
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
