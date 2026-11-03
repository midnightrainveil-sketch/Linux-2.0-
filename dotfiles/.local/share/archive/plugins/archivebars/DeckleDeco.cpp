#include "DeckleDeco.hpp"

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
#include <hyprland/src/render/pass/TexPassElement.hpp>
#include <hyprland/src/render/decorations/DecorationPositioner.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/config/values/types/IntValue.hpp>
#include <hyprland/src/config/values/types/FloatValue.hpp>
#include <hyprland/src/config/values/types/ColorValue.hpp>
#include <hyprland/src/config/lua/bindings/LuaBindingsInternal.hpp>
#include <hyprland/src/config/ConfigManager.hpp>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <unordered_map>

extern "C" {
#include <lua.h>
}

using namespace Render::GL;

// ---------------------------------------------------------------- state

namespace {
    struct SConfig {
        SP<Config::Values::CBoolValue>  enabled, grainDefault;
        SP<Config::Values::CIntValue>   margin, period, toneDepth;
        SP<Config::Values::CFloatValue> amplitude, rimWidth, shadowBlur, shadowX, shadowY, chips, creases, grain, size;
        SP<Config::Values::CFloatValue> liftBlur, liftX, liftY; // the focused window's shadow (0 = as the others)
        SP<Config::Values::CColorValue> paper, rimTop, rimBottom, rimTopInactive, rimBottomInactive, bevel, shadow, shadowInactive, tone, ticketEdge;
    };

    struct STileSet {
        Deckle::SStyle       style;
        // under the window
        SP<Render::ITexture> strips[4][Deckle::VARIANTS];
        SP<Render::ITexture> corners[4][Deckle::VARIANTS];
        // over it, drawn the first time they are needed
        bool                 overDrawn = false;
        SP<Render::ITexture> overStrips[4][Deckle::VARIANTS];
        SP<Render::ITexture> overCorners[4][Deckle::VARIANTS];
        SP<Render::ITexture> creases[4][Deckle::VARIANTS];
        uint64_t             lastUsed = 0;
    };

    HANDLE                          g_handle = nullptr;
    SConfig                         g_config;
    std::vector<WP<CArchiveDeckle>> g_deckles;
    std::vector<UP<STileSet>>       g_tiles;
    uint64_t                        g_tick        = 0;
    uint32_t                        g_noDeckleIdx = 0;
    uint32_t                        g_grainIdx    = 0;

    // the title-bar buttons as tickets, drawn once per look
    std::unordered_map<std::string, SP<Render::ITexture>> g_tickets;

    // the grain tile, in device pixels, redrawn when its strength changes
    SP<Render::ITexture>            g_grainTex;
    double                          g_grainStrength = -1;

    uint32_t                        argb(const SP<Config::Values::CColorValue>& v) {
        return static_cast<uint32_t>(v->value());
    }

    Deckle::SStyle styleFor(double scale, bool focused) {
        Deckle::SStyle st;
        st.scale      = scale;
        st.zoom       = std::clamp((double)g_config.size->value(), 0.5, 4.0);
        st.period     = std::clamp((int)g_config.period->value(), 32, 1024);
        st.margin     = std::clamp((int)g_config.margin->value(), 1, 32);
        st.toneDepth  = std::clamp((int)g_config.toneDepth->value(), 0, 64);
        st.amplitude  = std::clamp((double)g_config.amplitude->value(), 0.0, 4.0);
        st.rimWidth   = std::clamp((double)g_config.rimWidth->value(), 0.0, 6.0);
        st.shadowBlur = std::clamp((double)g_config.shadowBlur->value(), 0.0, 16.0);
        st.shadowX    = std::clamp((double)g_config.shadowX->value(), -16.0, 16.0);
        st.shadowY    = std::clamp((double)g_config.shadowY->value(), -16.0, 16.0);
        st.chips      = std::clamp((double)g_config.chips->value(), 0.0, 3.0);
        st.creases    = std::clamp((double)g_config.creases->value(), 0.0, 3.0);
        st.paper      = argb(g_config.paper);
        st.bevel      = argb(g_config.bevel);
        st.rimTop     = argb(g_config.rimTop);
        st.rimBottom  = argb(g_config.rimBottom);
        st.shadow     = argb(g_config.shadow);
        st.tone       = argb(g_config.tone);
        if (focused) {
            // the window in use is lifted off the desk: a wider, softer shadow
            // falling further from the light (0 = like the others)
            if (g_config.liftBlur->value() > 0)
                st.shadowBlur = std::clamp((double)g_config.liftBlur->value(), 0.0, 24.0);
            if (g_config.liftX->value() != 0)
                st.shadowX = std::clamp((double)g_config.liftX->value(), -24.0, 24.0);
            if (g_config.liftY->value() != 0)
                st.shadowY = std::clamp((double)g_config.liftY->value(), -24.0, 24.0);
        } else {
            // 0 means "same as focused"
            if (argb(g_config.rimTopInactive) != 0)
                st.rimTop = argb(g_config.rimTopInactive);
            if (argb(g_config.rimBottomInactive) != 0)
                st.rimBottom = argb(g_config.rimBottomInactive);
            if (argb(g_config.shadowInactive) != 0)
                st.shadow = argb(g_config.shadowInactive);
        }
        return st.sized();
    }

    // is there anything to draw over the window at all
    bool overlayWanted(const Deckle::SStyle& st) {
        return (((st.tone >> 24) & 0xff) > 0 && st.toneDepth > 0) || st.chips > 0 || st.creases > 0;
    }

    SP<Render::ITexture> upload(cairo_surface_t* s) {
        auto tex = g_pHyprRenderer->createTexture(s);
        cairo_surface_destroy(s);
        return tex;
    }

    // Tiles for one look, drawn on first use. A few looks are kept: focused
    // and unfocused, per monitor scale, and the previous palette while the
    // day/night change settles.
    STileSet* tilesFor(const Deckle::SStyle& st, bool over) {
        STileSet* set = nullptr;
        for (auto& t : g_tiles) {
            if (t->style == st) {
                set = t.get();
                break;
            }
        }

        if (!set) {
            auto fresh   = makeUnique<STileSet>();
            fresh->style = st;
            for (int s = 0; s < 4; ++s) {
                for (int v = 0; v < Deckle::VARIANTS; ++v) {
                    fresh->strips[s][v]  = upload(Deckle::strip(st, (Deckle::eSide)s, v));
                    fresh->corners[s][v] = upload(Deckle::corner(st, (Deckle::eCorner)s, v));
                }
            }
            if (g_tiles.size() >= 8) {
                auto oldest = std::ranges::min_element(g_tiles, {}, [](const auto& t) { return t->lastUsed; });
                g_tiles.erase(oldest);
            }
            g_tiles.emplace_back(std::move(fresh));
            set = g_tiles.back().get();
        }

        if (over && !set->overDrawn) {
            for (int s = 0; s < 4; ++s) {
                for (int v = 0; v < Deckle::VARIANTS; ++v) {
                    set->overStrips[s][v]  = upload(Deckle::overlayStrip(st, (Deckle::eSide)s, v));
                    set->overCorners[s][v] = upload(Deckle::overlayCorner(st, (Deckle::eCorner)s, v));
                    if (st.creases > 0)
                        set->creases[s][v] = upload(Deckle::crease(st, (Deckle::eCorner)s, v));
                }
            }
            set->overDrawn = true;
        }

        set->lastUsed = ++g_tick;
        return set;
    }

    double grainStrength() {
        return g_config.grain ? std::clamp((double)g_config.grain->value(), 0.0, 3.0) : 0.0;
    }

    SP<Render::ITexture> grainTexture() {
        const double strength = grainStrength();
        if (!g_grainTex || strength != g_grainStrength) {
            g_grainTex      = upload(Deckle::grainTile(512, strength));
            g_grainStrength = strength;
        }
        return g_grainTex;
    }

    bool edgesOn() {
        return g_config.enabled && g_config.enabled->value();
    }

    void damageAll() {
        for (auto& d : g_deckles) {
            if (d)
                d->damageEntire();
        }
    }
}

// ---------------------------------------------------------------- decoration

CArchiveDeckle::CArchiveDeckle(PHLWINDOW pWindow, bool over) : IHyprWindowDecoration(pWindow), m_window(pWindow), m_over(over) {
    // a stable seed per window, so its edge does not change while it lives;
    // both layers of a window share it, so tears line up with their notches
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
    return m_over ? DECORATION_LAYER_OVER : DECORATION_LAYER_BOTTOM;
}

uint64_t CArchiveDeckle::getDecorationFlags() {
    return DECORATION_NON_SOLID;
}

std::string CArchiveDeckle::getDisplayName() {
    return m_over ? "Archivedeckle over" : "Archivedeckle";
}

bool CArchiveDeckle::visible() {
    if (m_hidden || !validMapped(m_window))
        return false;
    const bool grain = m_over && grainOn();
    if (!edgesOn() && !grain)
        return false;

    const auto PWINDOW = m_window.lock();
    if (!PWINDOW->m_ruleApplicator->decorate().valueOrDefault())
        return false;
    // a fullscreen window is the whole sheet, not a card on it; a maximised
    // one is still a card (Hyprland keeps its bar), only a large one
    if (Fullscreen::controller()->getFullscreenModes(PWINDOW).internal == Fullscreen::FSMODE_FULLSCREEN)
        return false;
    if (m_over && !grain && !overlayWanted(styleFor(1.0, true)))
        return false;
    return true;
}

bool CArchiveDeckle::grainWanted() {
    return m_grainOverride.value_or(m_grainRule.value_or(g_config.grainDefault && g_config.grainDefault->value()));
}

bool CArchiveDeckle::grainOn() {
    return grainWanted() && grainStrength() > 0;
}

void CArchiveDeckle::toggleGrain() {
    m_grainOverride = !grainWanted();
    updateExtents();
    g_pDecorationPositioner->repositionDeco(this);
    damageEntire();
}

CBox CArchiveDeckle::cardBox() {
    const auto PWINDOW = m_window.lock();
    CBox       box     = g_pDecorationPositioner->getBoxWithIncludedDecos(PWINDOW);

    const auto PWORKSPACE      = PWINDOW->m_workspace;
    const auto WORKSPACEOFFSET = PWORKSPACE && !(PWINDOW->m_state & Desktop::View::WINDOW_STATE_PINNED) ? PWORKSPACE->m_renderOffset->value() : Vector2D();
    box.translate(WORKSPACEOFFSET).translate(PWINDOW->presentation().floatingOffset());

    return box.expand(styleFor(1.0, true).edge());
}

double CArchiveDeckle::reach() {
    // (the lifted shadow of the focused window reaches furthest; either, to be safe)
    return m_over ? styleFor(1.0, true).overOut() + 1 : std::max(styleFor(1.0, true).outset(), styleFor(1.0, false).outset()) + 1;
}

void CArchiveDeckle::updateExtents() {
    if (!visible()) {
        m_extents = {};
        return;
    }

    const auto PWINDOW = m_window.lock();
    const auto margin  = styleFor(1.0, true).edge();
    CBox       outer   = g_pDecorationPositioner->getBoxWithIncludedDecos(PWINDOW).expand(margin + reach());
    m_extents          = outer.extentsFrom(PWINDOW->getWindowMainSurfaceBox());
}

void CArchiveDeckle::fullscreenChanged() {
    damageEntire(); // where the old edge was
    updateExtents();
    g_pDecorationPositioner->repositionDeco(this);
}

void CArchiveDeckle::damageEntire() {
    if (!validMapped(m_window))
        return;
    g_pHyprRenderer->damageBox(cardBox().expand(reach()));
}

void CArchiveDeckle::updateRules() {
    const auto PWINDOW    = m_window.lock();
    const auto prevHidden = m_hidden;

    if (!PWINDOW)
        return;
    const auto& props = PWINDOW->m_ruleApplicator->m_otherProps.props;

    m_hidden = false;
    if (props.contains(g_noDeckleIdx))
        m_hidden = truthy(props.at(g_noDeckleIdx)->effect);

    const bool prevGrain = grainOn();
    m_grainRule.reset();
    if (props.contains(g_grainIdx))
        m_grainRule = truthy(props.at(g_grainIdx)->effect);
    if (grainOn() != prevGrain) {
        updateExtents();
        g_pDecorationPositioner->repositionDeco(this);
        damageEntire();
    }

    if (prevHidden != m_hidden) {
        updateExtents();
        g_pDecorationPositioner->repositionDeco(this);
    }
}

void CArchiveDeckle::draw(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float const& a, const Render::SWindowRenderPresentation& presentation) {
    updateExtents();
    if (m_extents != m_reportedExtents)
        g_pDecorationPositioner->repositionDeco(this);

    if (!visible())
        return;

    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CDecklePassElement>(CDecklePassElement::SData{this, a}));
}

void CArchiveDeckle::renderPass(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float const& a) {
    if (!visible())
        return;

    CBox card = cardBox();
    card.translate(-pMonitor->m_position);
    if (m_over)
        renderOver(ctx, pMonitor, a, card);
    else
        renderUnder(ctx, pMonitor, a, card);
}

// a tile from one of the tile arrays, or none if `v` is out of range
static const SP<Render::ITexture>& tile(const SP<Render::ITexture> (&row)[Deckle::VARIANTS], int v) {
    static const SP<Render::ITexture> NONE;
    return v >= 0 && v < Deckle::VARIANTS ? row[v] : NONE;
}

// logical edges -> a box in device pixels; neighbouring tiles share edges
static void put(Render::CRenderContext& ctx, const SP<Render::ITexture>& tex, double s, float a, double x0, double y0, double x1, double y1) {
    auto px  = [&](double v) { return std::round(v * s); };
    CBox box = {px(x0), px(y0), px(x1) - px(x0), px(y1) - px(y0)};
    if (!tex || box.w <= 0 || box.h <= 0)
        return;
    g_pHyprOpenGL->renderTexture(ctx, tex, box, {.a = a});
}

// run `fn(side, variant, a0, a1)` for every strip around a card, as deckle.cpp lays them
template <typename F>
static void forEachStrip(const Deckle::SStyle& st, uint32_t seed, double x, double y, double w, double h, F fn) {
    const double R = st.cornerReach();
    for (int side = 0; side < 4; ++side) {
        const bool   horizontal = side == Deckle::SIDE_TOP || side == Deckle::SIDE_BOTTOM;
        const double start = (horizontal ? x : y) + R, end = (horizontal ? x + w : y + h) - R;
        if (end - start < 1)
            continue;
        const int n = Deckle::stripCount(st, end - start);
        for (int i = 0; i < n; ++i)
            fn(side, Deckle::variantFor(seed, (Deckle::eSide)side, i), start + (end - start) * i / n, start + (end - start) * (i + 1) / n);
    }
}

void CArchiveDeckle::renderUnder(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float const& a, const CBox& card) {
    const auto PWINDOW = m_window.lock();
    const bool focused = PWINDOW == Desktop::focusState()->window();

    // the window in use rises off the desk and the one left settles: its
    // shadow eases between the two over a moment, drawn as the flat look
    // with the lifted one fading in over it
    const auto now = std::chrono::steady_clock::now();
    if (!m_liftStarted) {
        m_lift        = focused ? 1.0 : 0.0;
        m_liftStarted = true;
    } else {
        // (no frames are drawn while nothing changes: a long gap is one frame)
        const double dt     = std::min(0.04, std::chrono::duration<double>(now - m_liftTick).count());
        const double target = focused ? 1.0 : 0.0;
        const double step   = std::min(1.0, dt / 0.26);
        m_lift              = m_lift < target ? std::min(target, m_lift + step) : std::max(target, m_lift - step);
    }
    m_liftTick = now;
    const double eased = m_lift * m_lift * (3 - 2 * m_lift);
    if (eased <= 0.001 || eased >= 0.999)
        renderUnderStyle(ctx, pMonitor, a, card, styleFor(pMonitor->m_scale, eased >= 0.999));
    else {
        renderUnderStyle(ctx, pMonitor, a, card, styleFor(pMonitor->m_scale, false));
        renderUnderStyle(ctx, pMonitor, a * eased, card, styleFor(pMonitor->m_scale, true));
    }
    if (m_lift != (focused ? 1.0 : 0.0))
        damageEntire(); // (the next frame carries it on)
}

void CArchiveDeckle::renderUnderStyle(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float a, const CBox& card, const Deckle::SStyle& st) {
    STileSet* tiles = tilesFor(st, false);

    const double s = pMonitor->m_scale;
    const double O = st.outset(), I = st.inset(), R = st.cornerReach(), K = st.cornerSize();
    const double x = card.x, y = card.y, w = card.w, h = card.h;
    auto         px = [&](double v) { return std::round(v * s); };

    // paper under the window, seen while a client catches up with a resize
    {
        CBox inner = {px(x + I), px(y + I), px(x + w - I) - px(x + I), px(y + h - I) - px(y + I)};
        if (inner.w > 0 && inner.h > 0) {
            CHyprColor paper{static_cast<uint64_t>(st.paper | 0xff000000U)};
            paper.a *= a;
            g_pHyprOpenGL->renderRect(ctx, inner, paper, {.round = 0});
        }
    }

    // the edges: strips repeated along each side, stretched a little to fit
    forEachStrip(st, m_seed, x, y, w, h, [&](int side, int v, double a0, double a1) {
        const auto& tex = tile(tiles->strips[side], v);
        switch (side) {
            case Deckle::SIDE_TOP: put(ctx, tex, s, a, a0, y - O, a1, y + I); break;
            case Deckle::SIDE_BOTTOM: put(ctx, tex, s, a, a0, y + h - I, a1, y + h + O); break;
            case Deckle::SIDE_LEFT: put(ctx, tex, s, a, x - O, a0, x + I, a1); break;
            default: put(ctx, tex, s, a, x + w - I, a0, x + w + O, a1); break;
        }
    });

    // the four corners
    const double cx[4] = {x - O, x + w - R, x - O, x + w - R};
    const double cy[4] = {y - O, y - O, y + h - R, y + h - R};
    for (int c = 0; c < 4; ++c)
        put(ctx, tile(tiles->corners[c], Deckle::variantFor(m_seed, Deckle::SIDE_TOP, 1000 + c)), s, a, cx[c], cy[c], cx[c] + K, cy[c] + K);
}

void CArchiveDeckle::renderOver(Render::CRenderContext& ctx, PHLMONITOR pMonitor, float const& a, const CBox& card) {
    const auto   PWINDOW = m_window.lock();
    const bool   focused = PWINDOW == Desktop::focusState()->window();
    const auto   st      = styleFor(pMonitor->m_scale, focused);
    STileSet*    tiles   = tilesFor(st, true);

    const double s = pMonitor->m_scale;
    const double E = st.overOut(), D = st.depth(), R = st.cornerReach(), C = st.creaseSize();
    const double x = card.x, y = card.y, w = card.w, h = card.h;
    const bool   edges = edgesOn();

    // the grain, one tile repeated over the card's paper (inside the torn
    // edge), fixed to the card so it moves with the window
    if (grainOn()) {
        const auto   tex = grainTexture();
        const double in  = edges ? st.inset() : st.edge();
        auto         px  = [&](double v) { return std::round(v * s); };
        CBox         box = {px(x + in), px(y + in), px(x + w - in) - px(x + in), px(y + h - in) - px(y + in)};
        if (tex && tex->m_size.x > 0 && box.w > 0 && box.h > 0) {
            g_pHyprOpenGL->renderTexture(ctx, tex, box,
                                         {.a                           = a,
                                          .allowCustomUV               = true,
                                          .wrapX                       = WRAP_REPEAT,
                                          .wrapY                       = WRAP_REPEAT,
                                          .primarySurfaceUVTopLeft     = Vector2D{0, 0},
                                          .primarySurfaceUVBottomRight = Vector2D{box.w / tex->m_size.x, box.h / tex->m_size.y}});
        }
    }

    if (!edges || !overlayWanted(st))
        return;

    forEachStrip(st, m_seed, x, y, w, h, [&](int side, int v, double a0, double a1) {
        const auto& tex = tile(tiles->overStrips[side], v);
        switch (side) {
            case Deckle::SIDE_TOP: put(ctx, tex, s, a, a0, y - E, a1, y + D); break;
            case Deckle::SIDE_BOTTOM: put(ctx, tex, s, a, a0, y + h - D, a1, y + h + E); break;
            case Deckle::SIDE_LEFT: put(ctx, tex, s, a, x - E, a0, x + D, a1); break;
            default: put(ctx, tex, s, a, x + w - D, a0, x + w + E, a1); break;
        }
    });

    const double cx[4] = {x - E, x + w - R, x - E, x + w - R};
    const double cy[4] = {y - E, y - E, y + h - R, y + h - R};
    for (int c = 0; c < 4; ++c) {
        put(ctx, tile(tiles->overCorners[c], Deckle::variantFor(m_seed, Deckle::SIDE_TOP, 1000 + c)), s, a, cx[c], cy[c], cx[c] + E + R, cy[c] + E + R);

        const int v = Deckle::creaseFor(st, m_seed, (Deckle::eCorner)c, w, h);
        if (v < 0)
            continue;
        const double kx = (c == Deckle::CORNER_TR || c == Deckle::CORNER_BR) ? x + w - C : x;
        const double ky = (c == Deckle::CORNER_BL || c == Deckle::CORNER_BR) ? y + h - C : y;
        put(ctx, tile(tiles->creases[c], v), s, a, kx, ky, kx + C, ky + C);
    }
}

// ---------------------------------------------------------------- pass element

CDecklePassElement::CDecklePassElement(const SData& data) : m_data(data) {
    ;
}

std::vector<UP<IPassElement>> CDecklePassElement::draw(Render::CRenderContext& ctx) {
    m_data.deco->renderPass(ctx, ctx.m_data.pMonitor.lock(), m_data.a);
    return {};
}

bool CDecklePassElement::needsLiveBlur(Render::CRenderContext&) {
    return false;
}

bool CDecklePassElement::needsPrecomputeBlur(Render::CRenderContext&) {
    return false;
}

std::optional<CBox> CDecklePassElement::boundingBox(Render::CRenderContext& ctx) {
    return m_data.deco->cardBox().translate(-ctx.m_data.pMonitor->m_position).expand(m_data.deco->reach());
}

// ---------------------------------------------------------------- wiring

static int luaHasDeckle(lua_State* L) {
    lua_pushboolean(L, 1);
    return 1;
}

// grain on / off for the focused window; returns its new state
static int luaToggleGrain(lua_State* L) {
    const auto w = Desktop::focusState()->window();
    if (w)
        deckleToggleGrain(w);
    lua_pushboolean(L, w && deckleGrainOn(w));
    return 1;
}

static CArchiveDeckle* overOf(PHLWINDOW window) {
    for (auto& d : g_deckles) {
        if (d && d->isOver() && d->getOwner() == window)
            return d.get();
    }
    return nullptr;
}

bool deckleGrainOn(PHLWINDOW window) {
    const auto d = overOf(window);
    return d && d->grainOn();
}

void deckleToggleGrain(PHLWINDOW window) {
    if (const auto d = overOf(window); d)
        d->toggleGrain();
}

void deckleInit(HANDLE handle) {
    g_handle      = handle;
    g_noDeckleIdx = Desktop::Rule::windowEffects()->registerEffect("archivebars:no_deckle");
    g_grainIdx    = Desktop::Rule::windowEffects()->registerEffect("archivebars:grain");

    using namespace Config::Values;
    g_config.enabled           = makeShared<CBoolValue>("plugin:archivebars:deckle", "Torn paper edges around windows", false);
    g_config.margin            = makeShared<CIntValue>("plugin:archivebars:deckle_margin", "How far the card's edge sits outside the window", 6);
    g_config.period            = makeShared<CIntValue>("plugin:archivebars:deckle_period", "Length of one repeating edge strip", 160);
    g_config.toneDepth         = makeShared<CIntValue>("plugin:archivebars:deckle_tone_depth", "How far the aged edge reaches inward", 18);
    g_config.amplitude         = makeShared<CFloatValue>("plugin:archivebars:deckle_amplitude", "How far the torn edge wanders", 1.2F);
    g_config.rimWidth          = makeShared<CFloatValue>("plugin:archivebars:deckle_rim_width", "Weight of the edge's outline", 1.3F);
    g_config.shadowBlur        = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_blur", "Softness of the card's shadow", 4.5F);
    g_config.liftBlur          = makeShared<CFloatValue>("plugin:archivebars:deckle_lift_blur", "Softness of the focused window's shadow, lifted off the desk (0 = as the others)", 0.F);
    g_config.liftX             = makeShared<CFloatValue>("plugin:archivebars:deckle_lift_x", "The focused window's shadow offset, x (0 = as the others)", 0.F);
    g_config.liftY             = makeShared<CFloatValue>("plugin:archivebars:deckle_lift_y", "The focused window's shadow offset, y (0 = as the others)", 0.F);
    g_config.shadowX           = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_x", "Shadow offset, x", 1.5F);
    g_config.shadowY           = makeShared<CFloatValue>("plugin:archivebars:deckle_shadow_y", "Shadow offset, y", 3.F);
    g_config.chips             = makeShared<CFloatValue>("plugin:archivebars:deckle_chips", "How often edges are chipped, torn and wrinkled (0 = never)", 1.F);
    g_config.creases           = makeShared<CFloatValue>("plugin:archivebars:deckle_creases", "How often a corner is creased (0 = never)", 1.F);
    g_config.paper             = makeShared<CColorValue>("plugin:archivebars:deckle_paper", "The card's paper (match the window background)", 0xffd5d0ca);
    g_config.rimTop            = makeShared<CColorValue>("plugin:archivebars:deckle_rim_top", "Outline along the top edge", 0xffa09b94);
    g_config.rimBottom         = makeShared<CColorValue>("plugin:archivebars:deckle_rim_bottom", "Outline along the bottom edge", 0xff57524d);
    g_config.rimTopInactive    = makeShared<CColorValue>("plugin:archivebars:deckle_rim_top_inactive", "Top outline, unfocused (0 = as focused)", 0);
    g_config.rimBottomInactive = makeShared<CColorValue>("plugin:archivebars:deckle_rim_bottom_inactive", "Bottom outline, unfocused (0 = as focused)", 0);
    g_config.bevel             = makeShared<CColorValue>("plugin:archivebars:deckle_bevel", "Light: bevel, torn fibres, crease ridges", 0x59ffffff);
    g_config.shadow            = makeShared<CColorValue>("plugin:archivebars:deckle_shadow", "Shadow colour", 0x661e1d22);
    g_config.shadowInactive    = makeShared<CColorValue>("plugin:archivebars:deckle_shadow_inactive", "Shadow colour, unfocused (0 = as focused)", 0);
    g_config.grain             = makeShared<CFloatValue>("plugin:archivebars:grain", "Strength of the paper grain over windows that have it (0 = none)", 1.F);
    g_config.grainDefault      = makeShared<CBoolValue>("plugin:archivebars:grain_default", "Grain on windows no rule mentions", false);
    g_config.tone              = makeShared<CColorValue>("plugin:archivebars:deckle_tone", "The aged edge at its darkest (alpha = strength)", 0x30604c38);
    g_config.ticketEdge        = makeShared<CColorValue>("plugin:archivebars:ticket_edge", "Title-bar buttons as ticket stubs, edged in this colour (0 = round dots)", 0);
    g_config.size              = makeShared<CFloatValue>("plugin:archivebars:deckle_size", "Size of the whole edge: chips, tears, the cut, outline, shadow (1 = as drawn)", 1.F);

    for (const auto& v : std::initializer_list<SP<IValue>>{g_config.size, g_config.enabled, g_config.margin, g_config.period, g_config.toneDepth, g_config.amplitude, g_config.rimWidth,
                                                           g_config.shadowBlur, g_config.shadowX, g_config.shadowY, g_config.chips, g_config.creases, g_config.paper,
                                                           g_config.rimTop, g_config.rimBottom, g_config.rimTopInactive, g_config.rimBottomInactive, g_config.bevel,
                                                           g_config.shadow, g_config.shadowInactive, g_config.tone, g_config.grain, g_config.grainDefault,
                                                           g_config.ticketEdge, g_config.liftBlur, g_config.liftX, g_config.liftY})
        HyprlandAPI::addConfigValueV2(handle, v);

    // lets the config ask whether this build has the edges
    // (Hyprland's config is Lua only now)
    HyprlandAPI::addLuaFunction(handle, "archivebars", "has_deckle", ::luaHasDeckle);
    HyprlandAPI::addLuaFunction(handle, "archivebars", "has_deckle_size", ::luaHasDeckle);
    HyprlandAPI::addLuaFunction(handle, "archivebars", "toggle_grain", ::luaToggleGrain);
    HyprlandAPI::addLuaFunction(handle, "archivebars", "has_tickets", ::luaHasDeckle);
    HyprlandAPI::addLuaFunction(handle, "archivebars", "has_lift", ::luaHasDeckle);

    // the rim and shadow change with focus, outside the window's own damage
    static auto P1 = Event::bus()->m_events.window.active.listen([](PHLWINDOW, Desktop::eFocusReason) { damageAll(); });
    // into or out of fullscreen: the edge appears or goes, and the space it
    // takes with it (else a stale margin and the old edge stay on screen)
    static auto P3 = Event::bus()->m_events.window.fullscreen.listen([](PHLWINDOW w) {
        for (auto& d : g_deckles) {
            if (d && d->getOwner() == w)
                d->fullscreenChanged();
        }
        damageAll();
    });
    static auto P2 = Event::bus()->m_events.config.reloaded.listen([] {
        g_tiles.clear();
        g_grainTex = nullptr;
        for (auto& d : g_deckles) {
            if (d)
                g_pDecorationPositioner->repositionDeco(d.get());
        }
        damageAll();
    });
}

void deckleOnNewWindow(PHLWINDOW window) {
    // X11 programs (through XWayland) keep a plain frame: the torn edge
    // crashed Hyprland when RViz opened
    if (window->backend().isX11())
        return;
    if (std::ranges::any_of(window->presentation().decorations(), [](const auto& d) { return d->getDisplayName() == "Archivedeckle"; }))
        return;

    for (bool over : {false, true}) {
        auto deco    = makeShared<CArchiveDeckle>(window, over);
        deco->m_self = deco;
        g_deckles.emplace_back(deco);
        auto* added = deco.get();
        HyprlandAPI::addWindowDecoration(g_handle, window, std::move(deco));
        added->updateRules(); // the rules were applied before the window opened
    }
}

void deckleOnUpdateRules(PHLWINDOW window) {
    for (auto& d : g_deckles) {
        if (d && d->getOwner() == window)
            d->updateRules();
    }
}

void deckleExit() {
    g_pHyprRenderer->context().m_pass.removeAllOfType("CDecklePassElement");
    Desktop::Rule::windowEffects()->unregisterEffect(g_noDeckleIdx);
    Desktop::Rule::windowEffects()->unregisterEffect(g_grainIdx);
    g_tiles.clear();
    g_grainTex = nullptr;
    g_tickets.clear();
}

// ---------------------------------------------------------------- tickets

bool deckleTickets() {
    return g_config.ticketEdge && g_config.ticketEdge->value() != 0;
}

// The outline of a ticket stub grown by g: a rounded card with a round notch
// cut from the middle of each short side.
static void ticketShape(cairo_t* cr, double x0, double y0, double w, double h, double r, double nr, double g) {
    const double X0 = x0 - g, Y0 = y0 - g, W = w + 2 * g, H = h + 2 * g, R = r + g;
    cairo_new_path(cr);
    cairo_move_to(cr, X0 + R, Y0);
    cairo_line_to(cr, X0 + W - R, Y0);
    cairo_arc(cr, X0 + W - R, Y0 + R, R, -M_PI / 2, 0);
    cairo_line_to(cr, X0 + W, y0 + h / 2 - (nr - g));
    cairo_arc_negative(cr, X0 + W, y0 + h / 2, nr - g, -M_PI / 2, M_PI / 2);
    cairo_line_to(cr, X0 + W, Y0 + H - R);
    cairo_arc(cr, X0 + W - R, Y0 + H - R, R, 0, M_PI / 2);
    cairo_line_to(cr, X0 + R, Y0 + H);
    cairo_arc(cr, X0 + R, Y0 + H - R, R, M_PI / 2, M_PI);
    cairo_line_to(cr, X0, y0 + h / 2 + (nr - g));
    cairo_arc_negative(cr, X0, y0 + h / 2, nr - g, M_PI / 2, 3 * M_PI / 2);
    cairo_line_to(cr, X0, Y0 + R);
    cairo_arc(cr, X0 + R, Y0 + R, R, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);
}

static void setRGBA(cairo_t* cr, const CHyprColor& c, double a = 1.0) {
    cairo_set_source_rgba(cr, c.r, c.g, c.b, c.a * a);
}

SP<Render::ITexture> deckleTicket(const std::string& icon, const CHyprColor& ink, double width, double scale, bool lifted, double* pad) {
    const CHyprColor edge{static_cast<uint64_t>(g_config.ticketEdge->value())};
    const double     s = scale, P = std::ceil(5 * s);
    *pad               = P;

    // which mark: a cross (close), a dash (put away), a square (full sheet)
    int glyph = 2;
    if (icon == "x" || icon == "X" || icon == "×" || icon == "✕")
        glyph = 0;
    else if (icon == "-" || icon == "–" || icon == "—" || icon == "_")
        glyph = 1;

    char key[160];
    snprintf(key, sizeof key, "%d|%.4f,%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%.2f|%.3f|%d", glyph, ink.r, ink.g, ink.b, ink.a, edge.r, edge.g, edge.b, width, s, lifted ? 1 : 0);
    if (auto it = g_tickets.find(key); it != g_tickets.end() && it->second && it->second->m_texID != 0)
        return it->second;
    if (g_tickets.size() > 96)
        g_tickets.clear();

    const double w = std::round(width * s), h = std::round(width * 2.0 / 3.0 * s);
    const int    TW = static_cast<int>(w + 2 * P), TH = static_cast<int>(h + 2 * P);
    auto*        surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, TW, TH);
    auto*        cr   = cairo_create(surf);

    const double x0 = P, y0 = P - (lifted ? std::round(1 * s) : 0);
    const double ow = 1.2 * s, r = 1.6 * s, nr = h * 0.16;

    // its shadow on the paper (softer and further when lifted)
    const double sx = (lifted ? 0.9 : 0.6) * s, sy = (lifted ? 2.0 : 1.0) * s;
    for (int i = 0; i < 3; ++i) {
        cairo_save(cr);
        cairo_translate(cr, sx, sy);
        ticketShape(cr, x0, y0, w, h, r, nr, ow + (i - 1) * 0.5 * s);
        cairo_set_source_rgba(cr, 0, 0, 0, (lifted ? 0.10 : 0.08));
        cairo_fill(cr);
        cairo_restore(cr);
    }
    // the white edge, then the coloured card
    ticketShape(cr, x0, y0, w, h, r, nr, ow);
    setRGBA(cr, edge);
    cairo_fill(cr);
    ticketShape(cr, x0, y0, w, h, r, nr, 0);
    setRGBA(cr, ink);
    cairo_fill(cr);

    // the dashed tear line
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_BUTT);
    cairo_set_line_width(cr, std::max(1.0, 0.7 * s));
    const double tx = std::round(x0 + w * 0.30) + 0.5;
    for (int j = 0; j < 5; ++j) {
        const double yy = y0 + 1.6 * s + j * (h - 3.2 * s) / 4.4;
        cairo_move_to(cr, tx, yy);
        cairo_line_to(cr, tx, yy + 1.6 * s);
    }
    setRGBA(cr, edge, 0.78);
    cairo_stroke(cr);

    // the mark
    const double cx = x0 + w * 0.64, cy = y0 + h / 2, k = h * 0.2;
    cairo_set_line_width(cr, 1.6 * s);
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_SQUARE);
    if (glyph == 0) {
        cairo_move_to(cr, cx - k, cy - k);
        cairo_line_to(cr, cx + k, cy + k);
        cairo_move_to(cr, cx - k, cy + k);
        cairo_line_to(cr, cx + k, cy - k);
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
    } else if (glyph == 1) {
        cairo_move_to(cr, cx - k, cy);
        cairo_line_to(cr, cx + k, cy);
    } else
        cairo_rectangle(cr, cx - k * 0.85, cy - k * 0.85, k * 1.7, k * 1.7);
    setRGBA(cr, edge);
    cairo_stroke(cr);

    cairo_destroy(cr);
    cairo_surface_flush(surf);
    auto tex       = upload(surf);
    g_tickets[key] = tex;
    return tex;
}
