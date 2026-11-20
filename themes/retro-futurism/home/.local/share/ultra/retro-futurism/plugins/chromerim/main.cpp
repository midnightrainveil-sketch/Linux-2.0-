// chromerim: the Magnetic 88 theme's window rim (RimDeco.hpp says what
// it is). Built for the installed Hyprland by ultra-rim; loaded by the
// theme's hypr/theme/look.lua.
#define WLR_USE_UNSTABLE

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include "RimDeco.hpp"

// Do NOT change this function.
APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    const std::string HASH        = __hyprland_api_get_hash();
    const std::string CLIENT_HASH = __hyprland_api_get_client_hash();

    if (HASH != CLIENT_HASH) {
        HyprlandAPI::addNotification(handle, "[chromerim] Built for another Hyprland: run ultra-rim build", CHyprColor{1.0, 0.2, 0.2, 1.0}, 5000);
        throw std::runtime_error("[chromerim] version mismatch");
    }

    rimInit(handle);

    static auto P1 = Event::bus()->m_events.window.open.listen([](PHLWINDOW w) { rimOnNewWindow(w); });
    static auto P2 = Event::bus()->m_events.window.updateRules.listen([](PHLWINDOW w) { rimOnUpdateRules(w); });

    // the windows already open
    for (auto& w : Desktop::windowState()->windows()) {
        if (w->isHidden() || !validMapped(w))
            continue;
        rimOnNewWindow(w);
    }

    HyprlandAPI::reloadConfig();

    return {"chromerim", "The Magnetic 88 theme's chrome rim round windows.", "Linux 2.0", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    for (auto& m : State::monitorState()->monitors())
        m->m_scheduledRecalc = true;

    rimExit();
}
