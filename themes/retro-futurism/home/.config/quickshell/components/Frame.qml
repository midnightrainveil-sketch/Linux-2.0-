import QtQuick
import QtQuick.Shapes

// The window frame drawn by the shell: only where Hyprland's chromerim
// plugin does not draw it (X11 windows, or the plugin not built yet).
// The taskbar's own chrome, drawn (GPU paths, no picture), at its
// thickness (Theme.frameRim: 17 px, the tube's 22 px rim at the bar's size). Its profile was taken from the taskbar's rim in the mock-up
// (art/TaskbarEg.png), one ring a step from the outside in: each ring's top
// is the colour the bar's top rim has at that depth, its foot the colour
// its bottom rim has, so it is the same tube, lit from above.
// Inner corners rounded as the windows are (innerR); only the rim is drawn.
// (the samples: the mean of x 1060-1140 at y 320-341 and 418-397; the
// plugin's RimPaint.hpp has the same table)
Item {
    id: frame

    property real rim: 17
    property real innerR: 9                             // the windows' rounding (hypr look.lua)
    readonly property real u: rim / 18                   // 18 rings across the rim
    readonly property real outerR: innerR + rim
    property bool dim: false                            // a window not in use: the chrome a shade darker, still solid

    component Ring: ShapePath {
        id: ring
        property int d: 0
        property color top
        property color bottom
        strokeWidth: -1
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: 0; y2: frame.height
            GradientStop { position: 0.0; color: ring.top }
            GradientStop { position: Math.min(0.45, frame.rim * 2 / Math.max(1, frame.height)); color: ring.top }
            GradientStop { position: Math.max(0.55, 1 - frame.rim * 2 / Math.max(1, frame.height)); color: ring.bottom }
            GradientStop { position: 1.0; color: ring.bottom }
        }
        PathRectangle {
            x: ring.d * frame.u; y: ring.d * frame.u
            width: frame.width - 2 * ring.d * frame.u; height: frame.height - 2 * ring.d * frame.u
            radius: Math.max(0, frame.outerR - ring.d * frame.u)
        }
        // (each ring runs from its depth to the rim's inner edge, and the next
        // is laid over it: so only the outer edge is soft, and the rim solid)
        PathRectangle {
            x: frame.rim; y: frame.rim
            width: frame.width - 2 * frame.rim; height: frame.height - 2 * frame.rim
            radius: frame.innerR
        }
    }

    Shape {
        id: chrome
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        Ring { d: 0; top: "#a7a5a2"; bottom: "#696765" }
        Ring { d: 1; top: "#c8c6c2"; bottom: "#5a5856" }
        Ring { d: 2; top: "#dbd8d3"; bottom: "#62605e" }
        Ring { d: 3; top: "#d7d5d0"; bottom: "#6b6967" }
        Ring { d: 4; top: "#e3e0db"; bottom: "#767472" }
        Ring { d: 5; top: "#eeebe7"; bottom: "#7b7a77" }
        Ring { d: 6; top: "#f8f5f0"; bottom: "#858380" }
        Ring { d: 7; top: "#fdfaf5"; bottom: "#83827f" }
        Ring { d: 8; top: "#f7f4ef"; bottom: "#858380" }
        Ring { d: 9; top: "#d8d6d1"; bottom: "#aeaca9" }
        Ring { d: 10; top: "#aaa8a5"; bottom: "#f8f5f0" }
        Ring { d: 11; top: "#8f8d8a"; bottom: "#f6f3ee" }
        Ring { d: 12; top: "#84827f"; bottom: "#f4f1ec" }
        Ring { d: 13; top: "#858380"; bottom: "#efece7" }
        Ring { d: 14; top: "#8e8c89"; bottom: "#e0ddd9" }
        Ring { d: 15; top: "#a9a7a4"; bottom: "#c9c7c3" }
        Ring { d: 16; top: "#e6e3df"; bottom: "#aaa8a4" }
        Ring { d: 17; top: "#c7c5c1"; bottom: "#d5d2ce" }
        // (dimmed: a shade laid over the whole rim)
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillColor: frame.dim ? Qt.rgba(0.12, 0.10, 0.08, 0.32) : "transparent"
            PathRectangle { x: 0; y: 0; width: frame.width; height: frame.height; radius: frame.outerR }
            PathRectangle { x: frame.rim; y: frame.rim; width: frame.width - 2 * frame.rim; height: frame.height - 2 * frame.rim; radius: frame.innerR }
        }
    }
}
