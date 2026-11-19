pragma Singleton

import QtQuick
import Quickshell

// Retro Futurism: the look in one place. Black and white with a little
// blossom pink; hairlines, small capitals, one monospaced face.
Singleton {
    readonly property color ink: "#f2efed"            // text, lines
    readonly property color dim: "#a8a3a1"            // second voice
    readonly property color faint: "#5f5b5a"          // ticks, unexposed frames
    readonly property color panel: Qt.rgba(0.035, 0.033, 0.036, 0.86)
    readonly property color bar: Qt.rgba(0.03, 0.028, 0.031, 0.94)
    readonly property color accent: "#f4abc0"         // the blossom
    readonly property color warn: "#ee6a6a"

    readonly property string mono: "JetBrains Mono"
    readonly property real hair: 1                     // line weight

    readonly property int barTop: 0                   // (no bar at the top)
    readonly property real taskbarScale: 0.78          // the taskbar: the mock-up at this size
    readonly property int barBottom: 100              // ... and its height (128 x 0.78)
    // ---- the window frames (assets/frame.png, art/WindowFrame.png). These
    // and Hyprland's gaps (hypr/theme/look.lua) go together:
    //   gaps_out = frameMargin + frameRim + frameGap   (22 + 17 + 6 = 45)
    //   gaps_in  = frameRim + frameGap + 6             (29: 12 px between frames)
    readonly property real frameScale: 0.72            // the mock-up's frame at this size
    readonly property int frameMargin: 22              // screen edge to frame, and to the taskbar's ends
    readonly property int frameRim: 17                 // the rim's width on screen (24 x 0.72)
    readonly property int frameGap: 6                  // inside the rim, before the window
    readonly property int edge: 34                     // panels' distance from the screen edge
    readonly property int columnWidth: 364             // the right column

    readonly property int fade: 160
}
