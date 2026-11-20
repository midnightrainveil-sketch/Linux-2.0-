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
    readonly property real u: rim / 22                   // the mock-up's rim is 22 px deep
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
        Ring { d: 0; top: "#cac7c3"; bottom: "#4a4a47" }
        Ring { d: 1; top: "#878075"; bottom: "#1a1a17" }
        Ring { d: 2; top: "#e0d9d0"; bottom: "#23211d" }
        Ring { d: 3; top: "#cbc2b9"; bottom: "#4b473f" }
        Ring { d: 4; top: "#d6cdc4"; bottom: "#58534a" }
        Ring { d: 5; top: "#ece6de"; bottom: "#706b62" }
        Ring { d: 6; top: "#f9f7f1"; bottom: "#76716a" }
        Ring { d: 7; top: "#fcfcf8"; bottom: "#76716a" }
        Ring { d: 8; top: "#fffefd"; bottom: "#6b655e" }
        Ring { d: 9; top: "#f2f0ec"; bottom: "#534b45" }
        Ring { d: 10; top: "#918679"; bottom: "#98938d" }
        Ring { d: 11; top: "#5f5447"; bottom: "#fffffe" }
        Ring { d: 12; top: "#685f52"; bottom: "#f4f3f2" }
        Ring { d: 13; top: "#4b4035"; bottom: "#f5f4f1" }
        Ring { d: 14; top: "#493c30"; bottom: "#f2f1ed" }
        Ring { d: 15; top: "#7e7263"; bottom: "#e3e0dc" }
        Ring { d: 16; top: "#8b7d6c"; bottom: "#d8d5d0" }
        Ring { d: 17; top: "#8b7b66"; bottom: "#c0c0ba" }
        Ring { d: 18; top: "#d5cab2"; bottom: "#4e4a40" }
        Ring { d: 19; top: "#b6a88d"; bottom: "#8d806e" }
        Ring { d: 20; top: "#96886c"; bottom: "#f2dfc7" }
        Ring { d: 21; top: "#a29a81"; bottom: "#c9b9a1" }
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
