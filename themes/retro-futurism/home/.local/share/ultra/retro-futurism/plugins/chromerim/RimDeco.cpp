#include "RimDeco.hpp"
#include "RimPaint.hpp"

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleEffectContainer.hpp>
#include <hyprland/src/helpers/MiscFunctions.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/WindowRenderPresentation.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/state/workspace/State.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include <hyprland/src/output/Monitor.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <chrono>
#include <unordered_map>
#include <vector>

extern "C" {
#include <lua.h>
}

using namespace Render::GL;
using namespace RimPaint;

// ---------------------------------------------------------------- the rim

namespace {
    struct SConfig {
        SP<Config::Values::CBoolValue>  enabled;
        SP<Config::Values::CFloatValue> width, overlap;
        SP<Config::Values::CColorValue> dim;
        SP<Config::Values::CFloatValue> deskDim;
        SP<Config::Values::CColorValue> deskDimColor;
    };

    struct SPieces {
        SLook                look;
        int                  K = 0, D = 0; // a corner piece's side; the straight pieces' depth (device px)
        SP<Render::ITexture> corner[4]; // tl tr bl br
        SP<Render::ITexture> top, bottom, left, right;
        uint64_t             lastUsed = 0;
    };

    HANDLE                      g_handle = nullptr;
    SConfig                     g_config;
    std::vector<WP<CChromeRim>> g_rims;
    std::vector<UP<SPieces>>    g_pieces;
    uint64_t                    g_tick     = 0;
    uint32_t                    g_noRimIdx = 0;

    double rimWidth() {
        return std::clamp((double)g_config.width->value(), 1.0, 64.0);
    }

    double rimOverlap() {
        return std::clamp((double)g_config.overlap->value(), 0.0, 4.0);
    }

    // how far the rim reaches outside the window
    double rimOut() {
        return rimWidth() - rimOverlap();
    }

    bool rimsOn() {
        return g_config.enabled && g_config.enabled->value();
    }

    void damageAll() {
        for (auto& r : g_rims) {
            if (r)
                r->damageEntire();
        }
    }

    SP<Render::ITexture> upload(cairo_surface_t* s) {
        auto tex = g_pHyprRenderer->createTexture(s);
        cairo_surface_destroy(s);
        return tex;
    }

    SPieces* piecesFor(const SLook& lk) {
        for (auto& p : g_pieces) {
            if (p->look == lk) {
                p->lastUsed = ++g_tick;
                return p.get();
            }
        }

        auto        p = makeUnique<SPieces>();
        const SGeom g = geom(lk);
        p->look       = lk;
        p->K          = g.K;
        p->D          = g.D;
        for (int c = 0; c < 4; ++c)
            p->corner[c] = upload(corner(lk, c));
        p->top    = upload(run(lk, false));
        p->bottom = upload(run(lk, true));
        p->left   = upload(side(lk, false));
        p->right  = upload(side(lk, true));

        if (g_pieces.size() >= 8) {
            auto oldest = std::ranges::min_element(g_pieces, {}, [](const auto& q) { return q->lastUsed; });
            g_pieces.erase(oldest);
        }
        p->lastUsed = ++g_tick;
        g_pieces.emplace_back(std::move(p));
        return g_pieces.back().get();
    }

    void put(Render::CRenderContext& ctx, const SP<Render::ITexture>& tex, float a, int x, int y, int w, int h) {
        if (!tex || w <= 0 || h <= 0)
            return;
        CBox box = {(double)x, (double)y, (double)w, (double)h};
        g_pHyprOpenGL->renderTexture(ctx, tex, box, {.a = a});
    }
}

// ---------------------------------------------------------------- the desk, dimmed
//
// The picture behind the windows (the shell's Background layer) steps back
// while windows are open: a dark veil laid just after the wallpaper, under
// everything else. How dark follows the workspaces as Hyprland draws them,
// frame by frame: each workspace on the monitor that is in view counts by
// how much of it is in view (its slide or swipe offset), times whether it
// has windows (eased, so a window opening or the last one closing fades
// it). A swipe from a workspace with windows to an empty one brightens the
// picture as the fingers go.

namespace {
    std::unordered_map<const void*, double> g_occupied;     // per workspace, 0..1, eased
    std::chrono::steady_clock::time_point   g_lastDim = std::chrono::steady_clock::now();

    void renderDeskDim(Render::CRenderContext& ctx, PHLMONITOR mon) {
        if (!mon || !g_config.deskDim)
            return;
        const double strength = std::clamp((double)g_config.deskDim->value(), 0.0, 1.0);
        if (strength <= 0)
            return;

        const auto now = std::chrono::steady_clock::now();
        const double dt = std::clamp(std::chrono::duration<double>(now - g_lastDim).count(), 0.0, 0.1);
        g_lastDim       = now;

        const double w = std::max(1.0, mon->m_size.x), h = std::max(1.0, mon->m_size.y);
        double       dim    = 0;
        bool         easing = false;
        for (auto const& ref : State::Workspace::state()->workspaces()) {
            const auto ws = ref.lock();
            if (!ws || ws->m_monitor.lock() != mon || ws->type() == Workspace::eWorkspaceType::SPECIAL)
                continue;

            // has windows: eased over a quarter of a second
            const double target = ws->getWindowCount() > 0 ? 1.0 : 0.0;
            auto         it     = g_occupied.find(ws.get());
            if (it == g_occupied.end())
                it = g_occupied.emplace(ws.get(), target).first;
            double& occ = it->second;
            if (occ != target) {
                const double step = dt / 0.25;
                occ               = target > occ ? std::min(target, occ + step) : std::max(target, occ - step);
                easing            = true;
            }

            // in view: the one shown, and any sliding or being swiped
            const bool shown = ws == mon->m_activeWorkspace || ws->m_forceRendering || ws->m_renderOffset->isBeingAnimated();
            if (!shown)
                continue;
            const auto   off = ws->m_renderOffset->value();
            const double in  = std::clamp(1.0 - std::max(std::abs(off.x) / w, std::abs(off.y) / h), 0.0, 1.0);
            dim += in * occ;
        }
        if (easing)
            g_pHyprRenderer->damageMonitor(mon);

        dim = std::clamp(dim, 0.0, 1.0) * strength;
        if (dim <= 0.002)
            return;

        CHyprColor colour{static_cast<uint64_t>(g_config.deskDimColor->value())};
        colour.a = dim;
        CRectPassElement::SRectData data;
        data.box   = {0, 0, mon->m_transformedSize.x, mon->m_transformedSize.y};
        data.color = colour;
        Render::IHyprRenderer::addPassElement(ctx, makeUnique<CRectPassElement>(data));
    }
}

// ---------------------------------------------------------------- decoration

CChromeRim::CChromeRim(PHLWINDOW pWindow) : IHyprWindowDecoration(pWindow), m_window(pWindow) {
    ;
}

CChromeRim::~CChromeRim() {
    std::erase(g_rims, m_self);
}

PHLWINDOW CChromeRim::getOwner() {
    return m_window.lock();
}

SDecorationPositioningInfo CChromeRim::getPositioningInfo() {
    SDecorationPositioningInfo info;
    info.policy         = DECORATION_POSITION_ABSOLUTE;
    info.desiredExtents = m_extents;
    info.edges          = DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT | DECORATION_EDGE_TOP;

    m_reportedExtents = m_extents;
    return info;
}

void CChromeRim::onPositioningReply(const SDecorationPositioningReply& reply) {
    ;
}

eDecorationType CChromeRim::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CChromeRim::updateWindow(PHLWINDOW pWindow) {
    ;
}

eDecorationLayer CChromeRim::getDecorationLayer() {
    return DECORATION_LAYER_BOTTOM; // under the window: its corners round over the rim
}

uint64_t CChromeRim::getDecorationFlags() {
    return DECORATION_NON_SOLID;
}

std::string CChromeRim::getDisplayName() {
    return "Chromerim";
}

bool CChromeRim::visible() {
    if (m_hidden || !rimsOn() || !validMapped(m_window))
        return false;

    const auto PWINDOW = m_window.lock();
    if (!PWINDOW->m_ruleApplicator->decorate().valueOrDefault())
        return false;
    // a fullscreen window is the whole screen; a maximised one keeps its rim
    if (Fullscreen::controller()->getFullscreenModes(PWINDOW).internal == Fullscreen::FSMODE_FULLSCREEN)
        return false;
    return true;
}

CBox CChromeRim::rimBox(const Vector2D& offset) {
    return g_pDecorationPositioner->getBoxWithIncludedDecos(m_window.lock()).translate(offset).expand(rimOut());
}

CBox CChromeRim::rimBox() {
    const auto PRESENTATION = m_window->presentation().renderPresentation();
    return rimBox(PRESENTATION.workspaceOffset + PRESENTATION.floatingOffset);
}

void CChromeRim::updateExtents() {
    if (!visible()) {
        m_extents = {};
        return;
    }
    const double e = rimOut() + 1;
    m_extents      = {{e, e}, {e, e}};
}

void CChromeRim::refit() {
    damageEntire();
    updateExtents();
    g_pDecorationPositioner->repositionDeco(this);
    damageEntire();
}

void CChromeRim::damageEntire() {
    if (!validMapped(m_window))
        return;
    g_pHyprRenderer->damageBox(rimBox().expand(2));
}

void CChromeRim::updateRules() {
    const auto PWINDOW = m_window.lock();
    if (!PWINDOW)
        return;

    const auto  prevHidden = m_hidden;
    const auto& props      = PWINDOW->m_ruleApplicator->m_otherProps.props;
    m_hidden               = props.contains(g_noRimIdx) && truthy(props.at(g_noRimIdx)->effect);

    if (prevHidden != m_hidden)
        refit();
}

void CChromeRim::draw(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float const& a, const Render::SWindowRenderPresentation& presentation) {
    updateExtents();
    if (m_extents != m_reportedExtents)
        g_pDecorationPositioner->repositionDeco(this);

    if (!visible())
        return;

    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CRimPassElement>(CRimPassElement::SData{this, a, presentation.workspaceOffset + presentation.floatingOffset}));
}

void CChromeRim::renderPass(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float a, const Vector2D& offset) {
    if (!visible() || !pMonitor)
        return;

    const auto PWINDOW = m_window.lock();

    SLook      lk;
    lk.scale    = pMonitor->m_scale;
    lk.rounding = std::max(0.0, (double)PWINDOW->presentation().rounding());
    lk.focused  = PWINDOW == Desktop::focusState()->window();
    lk.width    = rimWidth();
    lk.overlap  = rimOverlap();
    lk.dim      = static_cast<uint32_t>(g_config.dim->value());
    if (lk.focused)
        lk.dim = 0; // (one look for every window in use, whatever the dim)
    SPieces*  p = piecesFor(lk);
    const int K = p->K, D = p->D;

    // the rim's outer edge in device px on this monitor; the pieces are laid
    // edge to edge on whole pixels, so they meet without seams
    CBox      box = rimBox(offset).translate(-pMonitor->m_position);
    const int x0 = std::lround(box.x * lk.scale), y0 = std::lround(box.y * lk.scale);
    const int x1 = std::lround((box.x + box.w) * lk.scale), y1 = std::lround((box.y + box.h) * lk.scale);
    const int w = x1 - x0, h = y1 - y0;
    if (w < 2 || h < 2)
        return;

    // (a window smaller than two corners: the corners shrink to fit)
    const int cw = std::min(K, w / 2), ch = std::min(K, h / 2);

    put(ctx, p->corner[0], a, x0, y0, cw, ch);
    put(ctx, p->corner[1], a, x1 - cw, y0, cw, ch);
    put(ctx, p->corner[2], a, x0, y1 - ch, cw, ch);
    put(ctx, p->corner[3], a, x1 - cw, y1 - ch, cw, ch);
    put(ctx, p->top, a, x0 + cw, y0, w - 2 * cw, D);
    put(ctx, p->bottom, a, x0 + cw, y1 - D, w - 2 * cw, D);
    put(ctx, p->left, a, x0, y0 + ch, D, h - 2 * ch);
    put(ctx, p->right, a, x1 - D, y0 + ch, D, h - 2 * ch);
}

// ---------------------------------------------------------------- pass element

CRimPassElement::CRimPassElement(const SData& data) : m_data(data) {
    ;
}

std::vector<UP<IPassElement>> CRimPassElement::draw(Render::CRenderContext& ctx) {
    m_data.deco->renderPass(ctx, ctx.m_data.pMonitor.lock(), m_data.a, m_data.offset);
    return {};
}

bool CRimPassElement::needsLiveBlur(Render::CRenderContext&) {
    return false;
}

bool CRimPassElement::needsPrecomputeBlur(Render::CRenderContext&) {
    return false;
}

std::optional<CBox> CRimPassElement::boundingBox(Render::CRenderContext& ctx) {
    return m_data.deco->rimBox(m_data.offset).translate(-ctx.m_data.pMonitor->m_position).expand(1);
}

// ---------------------------------------------------------------- wiring

static int luaHasRim(lua_State* L) {
    lua_pushboolean(L, 1);
    return 1;
}

void rimInit(HANDLE handle) {
    g_handle   = handle;
    g_noRimIdx = Desktop::Rule::windowEffects()->registerEffect("chromerim:no_rim");

    using namespace Config::Values;
    g_config.enabled = makeShared<CBoolValue>("plugin:chromerim:enabled", "The chrome rim round windows", true);
    g_config.width   = makeShared<CFloatValue>("plugin:chromerim:width", "The rim's depth, logical px (the taskbar's rim at its size)", 17.F);
    g_config.overlap = makeShared<CFloatValue>("plugin:chromerim:overlap", "How far the rim's inner edge lies under the window", 1.F);
    g_config.dim     = makeShared<CColorValue>("plugin:chromerim:dim", "Laid over the rim of a window not in use (alpha = how much)", 0x521f1a14);

    g_config.deskDim      = makeShared<CFloatValue>("plugin:chromerim:desk_dim", "How dark the picture behind the windows goes while they are open (0 = not at all)", 0.F);
    g_config.deskDimColor = makeShared<CColorValue>("plugin:chromerim:desk_dim_color", "The colour it darkens to", 0xff0d0907);

    for (const auto& v : std::initializer_list<SP<IValue>>{g_config.enabled, g_config.width, g_config.overlap, g_config.dim, g_config.deskDim, g_config.deskDimColor})
        HyprlandAPI::addConfigValueV2(handle, v);

    // lets the config (and the shell, through it) tell the rim is drawn here
    HyprlandAPI::addLuaFunction(handle, "chromerim", "has_rim", ::luaHasRim);
    HyprlandAPI::addLuaFunction(handle, "chromerim", "has_desk_dim", ::luaHasRim);

    // the desk's veil: just after the wallpaper, before everything else
    static auto P4 = Event::bus()->m_events.render.stage.listen([](const Event::SRenderStageEvent& e) {
        if (e.stage == RENDER_POST_WALLPAPER && e.context)
            renderDeskDim(e.context->get(), e.monitor);
    });

    // the rim darkens and brightens with focus, outside the window's own damage
    static auto P1 = Event::bus()->m_events.window.active.listen([](PHLWINDOW, Desktop::eFocusReason) { damageAll(); });
    // into or out of fullscreen: the rim goes or comes back, with its room
    static auto P2 = Event::bus()->m_events.window.fullscreen.listen([](PHLWINDOW w) {
        for (auto& r : g_rims) {
            if (r && r->getOwner() == w)
                r->refit();
        }
    });
    static auto P3 = Event::bus()->m_events.config.reloaded.listen([] {
        g_pieces.clear();
        for (auto& r : g_rims) {
            if (r)
                r->refit();
        }
    });
}

void rimOnNewWindow(PHLWINDOW window) {
    // X11 programs (through XWayland) keep the shell's frame: a decoration
    // over them crashed Hyprland once (the Archive theme's paper edge, RViz)
    if (window->backend().isX11())
        return;
    if (std::ranges::any_of(window->presentation().decorations(), [](const auto& d) { return d->getDisplayName() == "Chromerim"; }))
        return;

    auto deco    = makeShared<CChromeRim>(window);
    deco->m_self = deco;
    g_rims.emplace_back(deco);
    auto* added = deco.get();
    HyprlandAPI::addWindowDecoration(g_handle, window, std::move(deco));
    added->updateRules(); // the rules were applied before the window opened
}

void rimOnUpdateRules(PHLWINDOW window) {
    for (auto& r : g_rims) {
        if (r && r->getOwner() == window)
            r->updateRules();
    }
}

void rimExit() {
    g_pHyprRenderer->context().m_pass.removeAllOfType("CRimPassElement");
    Desktop::Rule::windowEffects()->unregisterEffect(g_noRimIdx);
    g_pieces.clear();
    g_occupied.clear();
}
