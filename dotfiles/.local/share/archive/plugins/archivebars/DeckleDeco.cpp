#include "DeckleDeco.hpp"

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleEffectContainer.hpp>
#include <hyprland/src/helpers/MiscFunctions.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp>
#include <hyprland/src/config/ConfigManager.hpp>

#include <algorithm>

extern "C" {
#include <lua.h>
}

using namespace Render::GL;

// ---------------------------------------------------------------- state

namespace {
    struct SConfig {
        SP<Config::Values::CBoolValue>  enabled;
        SP<Config::Values::CIntValue>   margin, period;
        SP<Config::Values::CFloatValue> amplitude, rimWidth, shadowBlur, shadowX, shadowY;
        SP<Config::Values::CColorValue> paper, rimTop, rimBottom, rimTopInactive, rimBottomInactive, bevel, shadow, shadowInactive;
    };

    struct STileSet {
        Deckle::SStyle       style;
        SP<Render::ITexture> strips[4][Deckle::VARIANTS];
        SP<Render::ITexture> corners[4][Deckle::VARIANTS];
        uint64_t             lastUsed = 0;
    };

    HANDLE                          g_handle = nullptr;
    SConfig                         g_config;
    std::vector<WP<CArchiveDeckle>> g_deckles;
    std::vector<UP<STileSet>>       g_tiles;
    uint64_t                        g_tick        = 0;
    uint32_t                        g_noDeckleIdx = 0;

    uint32_t                        argb(const SP<Config::Values::CColorValue>& v) {
        return static_cast<uint32_t>(v->value());
    }

    Deckle::SStyle styleFor(double scale, bool focused) {
        Deckle::SStyle st;
        st.scale      = scale;
        st.period     = std::clamp((int)g_config.period->value(), 32, 1024);
        st.margin     = std::clamp((int)g_config.margin->value(), 1, 32);
        st.amplitude  = std::clamp((double)g_config.amplitude->value(), 0.0, 4.0);
        st.rimWidth   = std::clamp((double)g_config.rimWidth->value(), 0.0, 6.0);
        st.shadowBlur = std::clamp((double)g_config.shadowBlur->value(), 0.0, 16.0);
        st.shadowX    = std::clamp((double)g_config.shadowX->value(), -16.0, 16.0);
        st.shadowY    = std::clamp((double)g_config.shadowY->value(), -16.0, 16.0);
        st.paper      = argb(g_config.paper);
        st.bevel      = argb(g_config.bevel);
        st.rimTop     = argb(g_config.rimTop);
        st.rimBottom  = argb(g_config.rimBottom);
        st.shadow     = argb(g_config.shadow);
        if (!focused) {
            // 0 means "same as focused"
            if (argb(g_config.rimTopInactive) != 0)
                st.rimTop = argb(g_config.rimTopInactive);
            if (argb(g_config.rimBottomInactive) != 0)
                st.rimBottom = argb(g_config.rimBottomInactive);
            if (argb(g_config.shadowInactive) != 0)
                st.shadow = argb(g_config.shadowInactive);
        }
        return st;
    }

    // Tiles for one look, drawn on first use. A few looks are kept: focused
    // and unfocused, per monitor scale, and the previous palette while the
    // day/night change settles.
    STileSet* tilesFor(const Deckle::SStyle& st) {
        for (auto& t : g_tiles) {
            if (t->style == st) {
                t->lastUsed = ++g_tick;
                return t.get();
            }
        }

        auto set      = makeUnique<STileSet>();
        set->style    = st;
        set->lastUsed = ++g_tick;
        auto upload   = [](cairo_surface_t* s) {
            auto tex = g_pHyprRenderer->createTexture(s);
            cairo_surface_destroy(s);
            return tex;
        };
        for (int s = 0; s < 4; ++s) {
            for (int v = 0; v < Deckle::VARIANTS; ++v) {
                set->strips[s][v]  = upload(Deckle::strip(st, (Deckle::eSide)s, v));
                set->corners[s][v] = upload(Deckle::corner(st, (Deckle::eCorner)s, v));
            }
        }

        if (g_tiles.size() >= 8) {
            auto oldest = std::ranges::min_element(g_tiles, {}, [](const auto& t) { return t->lastUsed; });
            g_tiles.erase(oldest);
        }
        g_tiles.emplace_back(std::move(set));
        return g_tiles.back().get();
    }

    void damageAll() {
        for (auto& d : g_deckles) {
            if (d)
                d->damageEntire();
        }
    }
}

// ---------------------------------------------------------------- decoration

CArchiveDeckle::CArchiveDeckle(PHLWINDOW pWindow) : IHyprWindowDecoration(pWindow), m_window(pWindow) {
    // a stable seed per window, so its edge does not change while it lives
    m_seed = static_cast<uint32_t>(reinterpret_cast<uintptr_t>(pWindow.get()) >> 4) * 2654435761U;
}

CArchiveDeckle::~CArchiveDeckle() {
    std::erase(g_deckles, m_self);
}

PHLWINDOW CArchiveDeckle::getOwner() {
    return m_window.lock();
}

SDecorationPositioningInfo CArchiveDeckle::getPositioningInfo() {
    SDecorationPositioningInfo info;
    info.policy         = DECORATION_POSITION_ABSOLUTE;
    info.desiredExtents = m_extents;
    info.edges          = DECORATION_EDGE_BOTTOM | DECORATION_EDGE_LEFT | DECORATION_EDGE_RIGHT | DECORATION_EDGE_TOP;

    m_reportedExtents = m_extents;
    return info;
}

void CArchiveDeckle::onPositioningReply(const SDecorationPositioningReply& reply) {
    ;
}

eDecorationType CArchiveDeckle::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CArchiveDeckle::updateWindow(PHLWINDOW pWindow) {
    ;
}

eDecorationLayer CArchiveDeckle::getDecorationLayer() {
    return DECORATION_LAYER_BOTTOM;
}

uint64_t CArchiveDeckle::getDecorationFlags() {
    return DECORATION_NON_SOLID;
}

std::string CArchiveDeckle::getDisplayName() {
    return "Archivedeckle";
}

bool CArchiveDeckle::visible() {
    if (!g_config.enabled || !g_config.enabled->value() || m_hidden || !validMapped(m_window))
        return false;

    const auto PWINDOW = m_window.lock();
    if (!PWINDOW->m_ruleApplicator->decorate().valueOrDefault())
        return false;
    // a fullscreen window is the whole sheet, not a card on it
    if (Fullscreen::controller()->isFullscreen(PWINDOW))
        return false;
    return true;
}

CBox CArchiveDeckle::cardBox() {
    const auto PWINDOW = m_window.lock();
    CBox       box     = g_pDecorationPositioner->getBoxWithIncludedDecos(PWINDOW);

    const auto PWORKSPACE      = PWINDOW->m_workspace;
    const auto WORKSPACEOFFSET = PWORKSPACE && !PWINDOW->m_pinned ? PWORKSPACE->m_renderOffset->value() : Vector2D();
    box.translate(WORKSPACEOFFSET).translate(PWINDOW->m_floatingOffset);

    return box.expand(std::clamp((int)g_config.margin->value(), 1, 32));
}

void CArchiveDeckle::updateExtents() {
    if (!visible()) {
        m_extents = {};
        return;
    }

    const auto PWINDOW = m_window.lock();
    const auto st      = styleFor(1.0, true);
    CBox       outer   = g_pDecorationPositioner->getBoxWithIncludedDecos(PWINDOW).expand(st.margin + st.outset() + 1);
    m_extents          = outer.extentsFrom(PWINDOW->getWindowMainSurfaceBox());
}

void CArchiveDeckle::damageEntire() {
    if (!validMapped(m_window))
        return;
    const auto st = styleFor(1.0, true);
    g_pHyprRenderer->damageBox(cardBox().expand(st.outset() + 1));
}

void CArchiveDeckle::updateRules() {
    const auto PWINDOW    = m_window.lock();
    const auto prevHidden = m_hidden;

    m_hidden = false;
    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_noDeckleIdx))
        m_hidden = truthy(PWINDOW->m_ruleApplicator->m_otherProps.props.at(g_noDeckleIdx)->effect);

    if (prevHidden != m_hidden) {
        updateExtents();
        g_pDecorationPositioner->repositionDeco(this);
    }
}

void CArchiveDeckle::draw(PHLMONITOR pMonitor, float const& a) {
    updateExtents();
    if (m_extents != m_reportedExtents)
        g_pDecorationPositioner->repositionDeco(this);

    if (!visible())
        return;

    g_pHyprRenderer->m_renderPass.add(makeUnique<CDecklePassElement>(CDecklePassElement::SData{this, a}));
}

void CArchiveDeckle::renderPass(PHLMONITOR pMonitor, float const& a) {
    if (!visible())
        return;

    const auto  PWINDOW = m_window.lock();
    const bool  focused = PWINDOW == Desktop::focusState()->window();
    const auto  st      = styleFor(pMonitor->m_scale, focused);
    STileSet*   tiles   = tilesFor(st);

    CBox        card = cardBox();
    card.translate(-pMonitor->m_position);

    const double s = pMonitor->m_scale;
    const double O = st.outset(), I = st.inset(), R = st.cornerReach(), K = st.cornerSize();
    const double x = card.x, y = card.y, w = card.w, h = card.h;

    // logical edges -> a box in device pixels; neighbouring tiles share edges
    auto px  = [&](double v) { return std::round(v * s); };
    auto put = [&](const SP<Render::ITexture>& tex, double x0, double y0, double x1, double y1) {
        CBox box = {px(x0), px(y0), px(x1) - px(x0), px(y1) - px(y0)};
        if (!tex || box.w <= 0 || box.h <= 0)
            return;
        g_pHyprOpenGL->renderTexture(tex, box, {.a = a});
    };

    // paper under the window, seen while a client catches up with a resize
    {
        CBox inner = {px(x + I), px(y + I), px(x + w - I) - px(x + I), px(y + h - I) - px(y + I)};
        if (inner.w > 0 && inner.h > 0) {
            CHyprColor paper{static_cast<uint64_t>(st.paper | 0xff000000U)};
            paper.a *= a;
            g_pHyprOpenGL->renderRect(inner, paper, {.round = 0});
        }
    }

    // the edges: strips repeated along each side, stretched a little to fit
    for (int side = 0; side < 4; ++side) {
        const bool   horizontal = side == Deckle::SIDE_TOP || side == Deckle::SIDE_BOTTOM;
        const double start = (horizontal ? x : y) + R, end = (horizontal ? x + w : y + h) - R;
        if (end - start < 1)
            continue;
        const int n = Deckle::stripCount(st, end - start);
        for (int i = 0; i < n; ++i) {
            const double a0  = start + (end - start) * i / n;
            const double a1  = start + (end - start) * (i + 1) / n;
            const auto&  tex = tiles->strips[side][Deckle::variantFor(m_seed, (Deckle::eSide)side, i)];
            switch (side) {
                case Deckle::SIDE_TOP: put(tex, a0, y - O, a1, y + I); break;
                case Deckle::SIDE_BOTTOM: put(tex, a0, y + h - I, a1, y + h + O); break;
                case Deckle::SIDE_LEFT: put(tex, x - O, a0, x + I, a1); break;
                default: put(tex, x + w - I, a0, x + w + O, a1); break;
            }
        }
    }

    // the four corners
    const double cx[4] = {x - O, x + w - R, x - O, x + w - R};
    const double cy[4] = {y - O, y - O, y + h - R, y + h - R};
    for (int c = 0; c < 4; ++c) {
        const auto& tex = tiles->corners[c][Deckle::variantFor(m_seed, Deckle::SIDE_TOP, 1000 + c)];
        put(tex, cx[c], cy[c], cx[c] + K, cy[c] + K);
    }
}

// ---------------------------------------------------------------- pass element

CDecklePassElement::CDecklePassElement(const SData& data) : m_data(data) {
    ;
}

std::vector<UP<IPassElement>> CDecklePassElement::draw() {
    m_data.deco->renderPass(g_pHyprRenderer->m_renderData.pMonitor.lock(), m_data.a);
    return {};
}

bool CDecklePassElement::needsLiveBlur() {
    return false;
}

bool CDecklePassElement::needsPrecomputeBlur() {
    return false;
}

std::optional<CBox> CDecklePassElement::boundingBox() {
    const auto st = styleFor(1.0, true);
    return m_data.deco->cardBox().translate(-g_pHyprRenderer->m_renderData.pMonitor->m_position).expand(st.outset() + 1);
}

// ---------------------------------------------------------------- wiring

static int luaHasDeckle(lua_State* L) {
    lua_pushboolean(L, 1);
    return 1;
}

void deckleInit(HANDLE handle) {
    g_handle      = handle;
    g_noDeckleIdx = Desktop::Rule::windowEffects()->registerEffect("archivebars:no_deckle");

    using namespace Config::Values;
    g_config.enabled           = makeShared<CBoolValue>("plugin:archivebars:deckle", "Torn paper edges around windows", false);
    g_config.margin            = makeShared<CIntValue>("plugin:archivebars:deckle_margin", "How far the card's edge sits outside the window", 4);
    g_config.period            = makeShared<CIntValue>("plugin:archivebars:deckle_period", "Length of one repeating edge strip", 160);
    g_config.amplitude         = makeShared<CFloatValue>("plugin:archivebars:deckle_amplitude", "How far the torn edge wanders", 1.2F);
    g_config.rimWidth          = makeShared<CFloatValue>("plugin:archivebars:deckle_rim_width", "Weight of the edge's outline", 1.3F);
    g_config.shadowBlur        = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_blur", "Softness of the card's shadow", 4.F);
    g_config.shadowX           = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_x", "Shadow offset, x", -0.5F);
    g_config.shadowY           = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_y", "Shadow offset, y", 2.5F);
    g_config.paper             = makeShared<CColorValue>("plugin:archivebars:deckle_paper", "The card's paper (match the window background)", 0xffd5d0ca);
    g_config.rimTop            = makeShared<CColorValue>("plugin:archivebars:deckle_rim_top", "Outline along the top edge", 0xffa09b94);
    g_config.rimBottom         = makeShared<CColorValue>("plugin:archivebars:deckle_rim_bottom", "Outline along the bottom edge", 0xff57524d);
    g_config.rimTopInactive    = makeShared<CColorValue>("plugin:archivebars:deckle_rim_top_inactive", "Top outline, unfocused (0 = as focused)", 0);
    g_config.rimBottomInactive = makeShared<CColorValue>("plugin:archivebars:deckle_rim_bottom_inactive", "Bottom outline, unfocused (0 = as focused)", 0);
    g_config.bevel             = makeShared<CColorValue>("plugin:archivebars:deckle_bevel", "Light line just inside the edge", 0x59ffffff);
    g_config.shadow            = makeShared<CColorValue>("plugin:archivebars:deckle_shadow", "Shadow colour", 0x661e1d22);
    g_config.shadowInactive    = makeShared<CColorValue>("plugin:archivebars:deckle_shadow_inactive", "Shadow colour, unfocused (0 = as focused)", 0);

    for (const auto& v : std::initializer_list<SP<IValue>>{g_config.enabled, g_config.margin, g_config.period, g_config.amplitude, g_config.rimWidth, g_config.shadowBlur,
                                                           g_config.shadowX, g_config.shadowY, g_config.paper, g_config.rimTop, g_config.rimBottom, g_config.rimTopInactive,
                                                           g_config.rimBottomInactive, g_config.bevel, g_config.shadow, g_config.shadowInactive})
        HyprlandAPI::addConfigValueV2(handle, v);

    // lets the config ask whether this build has the edges
    if (Config::mgr()->type() != Config::CONFIG_LEGACY)
        HyprlandAPI::addLuaFunction(handle, "archivebars", "has_deckle", ::luaHasDeckle);

    // the rim and shadow change with focus, outside the window's own damage
    static auto P1 = Event::bus()->m_events.window.active.listen([](PHLWINDOW, Desktop::eFocusReason) { damageAll(); });
    static auto P2 = Event::bus()->m_events.config.reloaded.listen([] {
        g_tiles.clear();
        for (auto& d : g_deckles) {
            if (d)
                g_pDecorationPositioner->repositionDeco(d.get());
        }
        damageAll();
    });
}

void deckleOnNewWindow(PHLWINDOW window) {
    if (window->m_X11DoesntWantBorders)
        return;
    if (std::ranges::any_of(window->m_windowDecorations, [](const auto& d) { return d->getDisplayName() == "Archivedeckle"; }))
        return;

    auto deco    = makeUnique<CArchiveDeckle>(window);
    deco->m_self = deco;
    g_deckles.emplace_back(deco);
    HyprlandAPI::addWindowDecoration(g_handle, window, std::move(deco));
}

void deckleOnUpdateRules(PHLWINDOW window) {
    for (auto& d : g_deckles) {
        if (d && d->getOwner() == window) {
            d->updateRules();
            return;
        }
    }
}

void deckleExit() {
    g_pHyprRenderer->m_renderPass.removeAllOfType("CDecklePassElement");
    Desktop::Rule::windowEffects()->unregisterEffect(g_noDeckleIdx);
    g_tiles.clear();
}
