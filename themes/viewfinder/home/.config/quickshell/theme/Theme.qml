pragma Singleton

import QtQuick
import Quickshell

// Viewfinder: the look in one place. Black and white with a little
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

    readonly property int barTop: 46
    readonly property int barBottom: 58
    readonly property int edge: 34                     // panels' distance from the screen edge
    readonly property int stripWidth: 172
    readonly property int columnWidth: 364             // the right column

    readonly property int fade: 160
}
