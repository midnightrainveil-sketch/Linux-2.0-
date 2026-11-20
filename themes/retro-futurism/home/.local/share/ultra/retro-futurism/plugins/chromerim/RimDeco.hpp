#pragma once

// chromerim: the taskbar's chrome rim round every window, drawn by Hyprland
// itself, as it draws its own borders: a decoration on the window, so it
// moves, slides, resizes and changes workspace with it, in the same frame.
//
// The rim is the taskbar's (the mock-up's art/TaskbarEg.png), at its depth
// on screen: 22 bands from the outside in, its inner lip included, each
// with the colour the bar's top rim has at that depth and the colour its
// bottom rim has, so it is the same tube, lit from above.
// It is drawn once per look (monitor scale, in use or not) into a few small
// pieces, the four corners and a slice of each side, and those are laid
// round the window at any size: resizing costs nothing.
//
// The rim's inner edge lies a pixel under the window, rounded as the window
// is (decoration:rounding), so the two touch with no gap.

#define WLR_USE_UNSTABLE

#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>
#include <hyprland/src/render/Context.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

class CChromeRim : public IHyprWindowDecoration {
  public:
    CChromeRim(PHLWINDOW);
    virtual ~CChromeRim();

    virtual SDecorationPositioningInfo getPositioningInfo();
    virtual void                       onPositioningReply(const SDecorationPositioningReply& reply);
    virtual void                       draw(Render::CRenderContext& ctx, PHLMONITOR, float const& a, const Render::SWindowRenderPresentation& presentation);
    virtual eDecorationType            getDecorationType();
    virtual void                       updateWindow(PHLWINDOW);
    virtual void                       damageEntire();
    virtual eDecorationLayer           getDecorationLayer();
    virtual uint64_t                   getDecorationFlags();
    virtual std::string                getDisplayName();

    PHLWINDOW                          getOwner();
    void                               updateRules();
    void                               refit(); // the space it takes changed (fullscreen, config)

    WP<CChromeRim>                     m_self;

  private:
    PHLWINDOWREF m_window;
    SBoxExtents  m_extents;
    SBoxExtents  m_reportedExtents;
    bool         m_hidden = false;

    bool         visible();
    // the rim's outer edge, global logical px, following the workspace's
    // slide and the window's floating offset (as this frame draws them, or
    // as they are now)
    CBox         rimBox(const Vector2D& offset);
    CBox         rimBox();
    void         updateExtents();
    void         renderPass(Render::CRenderContext& ctx, PHLMONITOR, float a, const Vector2D& offset);

    friend class CRimPassElement;
};

class CRimPassElement : public IPassElement {
  public:
    struct SData {
        CChromeRim* deco = nullptr;
        float       a    = 1.F;
        Vector2D    offset; // the workspace's slide and the floating offset, this frame
    };

    CRimPassElement(const SData& data);
    virtual ~CRimPassElement() = default;

    virtual std::vector<UP<IPassElement>> draw(Render::CRenderContext& ctx) override;
    virtual bool                          needsLiveBlur(Render::CRenderContext&) override;
    virtual bool                          needsPrecomputeBlur(Render::CRenderContext&) override;
    virtual std::optional<CBox>           boundingBox(Render::CRenderContext& ctx) override;

    virtual const char*                   passName() override {
        return "CRimPassElement";
    }

    virtual ePassElementType type() override {
        return EK_CUSTOM;
    }

  private:
    SData m_data;
};

// wiring, called from main.cpp
void rimInit(HANDLE handle);
void rimOnNewWindow(PHLWINDOW window);
void rimOnUpdateRules(PHLWINDOW window);
void rimExit();
