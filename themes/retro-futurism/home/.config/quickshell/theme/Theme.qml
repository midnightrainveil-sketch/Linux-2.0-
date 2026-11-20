pragma Singleton

import QtQuick
import Quickshell

// Magnetic 88: the look in one place, for the plain panels (the
// notifications, the themes list): Magnetic 88's cream plates, charcoal
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
    // the taskbar's tube: its top this far above the screen's bottom (its
    // foot on the windows' rims, frameMargin up; the tube 98 px of the
    // mock-up high)
    readonly property real taskbarReach: frameMargin + 98 * taskbarScale
    // ---- the window frames: the taskbar's chrome, drawn (components/Frame.qml).
    // These and Hyprland's gaps and rounding (hypr/theme/look.lua) go together:
    //   gaps_out = frameMargin + frameRim + frameGap   (22 + 17 - 1 = 38)
    //   gaps_in  = frameRim + frameGap + 3             (19: 6 px between frames)
    //   rounding = windowRounding
    readonly property int frameMargin: 22              // screen edge to frame, and to the taskbar's ends
    readonly property int frameRim: 17                 // the chrome's width: the taskbar rim's (22 x 0.78)
    readonly property int frameGap: -1                 // its inner edge 1 px under the window: they touch
    // the windows' corners: rounded so the rim round them (frameRim deep)
    // bends as the taskbar's ends do (its tube 98 px of the mock-up high,
    // ends round: an outer radius of 49 x 0.78 = 38)
    readonly property int windowRounding: 21
    readonly property int edge: 34                     // panels' distance from the screen edge
    readonly property int columnWidth: 380             // the notifications' width

    readonly property int fade: 160
}
