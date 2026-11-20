pragma Singleton

import QtQuick
import Quickshell

// Retro Futurism: the look in one place, for the plain panels (the
// notifications, the themes list): Cassette OS's cream plates, charcoal
// lettering in Barlow, rust for what matters. (The gadgets have their own
// pictures; see widgets/.)
Singleton {
    readonly property color ink: "#35312a"            // lettering, lines
    readonly property color dim: "#7a7162"            // second voice
    readonly property color faint: "#b5a88f"          // ticks
    readonly property color panel: Qt.rgba(0.953, 0.925, 0.871, 0.97)   // the cream plate
    readonly property color bar: Qt.rgba(0.953, 0.925, 0.871, 0.97)
    readonly property color accent: "#b2512f"         // rust
    readonly property color warn: "#c4462a"
    readonly property color paper: "#f4ebdc"          // lettering on ink

    readonly property string mono: "Barlow"
    readonly property real hair: 1                     // line weight

    readonly property int barTop: 0                   // (no bar at the top)
    readonly property real taskbarScale: 0.78          // the taskbar: the mock-up at this size
    readonly property int barBottom: 100              // ... and its height (128 x 0.78)
    // the taskbar's tube: its top this far above the screen's bottom (the
    // panel's height less the 8 px of air over the tube in the mock-up)
    readonly property real taskbarReach: Math.ceil(128 * taskbarScale) - 8 * taskbarScale
    // ---- the window frames: a drawn chrome border (components/Frame.qml).
    // These and Hyprland's gaps and rounding (hypr/theme/look.lua) go together:
    //   gaps_out = frameMargin + frameRim + frameGap   (22 + 9 - 1 = 30)
    //   gaps_in  = frameRim + frameGap + 3             (11: 6 px between frames)
    //   rounding = windowRounding
    readonly property int frameMargin: 22              // screen edge to frame, and to the taskbar's ends
    readonly property int frameRim: 9                  // the chrome's width
    readonly property int frameGap: -1                 // its inner edge 1 px under the window: they touch
    readonly property int windowRounding: 9
    readonly property int edge: 34                     // panels' distance from the screen edge
    readonly property int columnWidth: 380             // the notifications' width

    readonly property int fade: 160
}
