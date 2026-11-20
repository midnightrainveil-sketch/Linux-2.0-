import QtQuick
import QtQuick.Shapes

// The window frame: a chrome border, drawn (a few GPU paths, no picture),
// so it takes any size and any rim width. From the outside in, in 12ths of
// the rim:
//   0 - 1     its outer edge, a little dark
//   1 - 10    the chrome, bright at the top, cooler toward the foot, with
//             a fine highlight along it (2.5 - 3.5)
//   10 - 12   a dark seam where it meets the window
// Its inner corners are rounded as the windows are (innerR); its outer ones
// that plus the rim. Only the rim is drawn: inside it, nothing.
Item {
    id: frame

    property real rim: 9
    property real innerR: 9                             // the windows' rounding (hypr look.lua)
    readonly property real u: rim / 12
    readonly property real outerR: innerR + rim

    component Ring: ShapePath {
        id: ring
        property real a: 0
        property real b: 12
        property var stops: []
        strokeWidth: -1
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: 0; y2: frame.height
            GradientStop { position: 0.0; color: ring.stops[0] }
            GradientStop { position: 0.06; color: ring.stops[1] }
            GradientStop { position: 0.94; color: ring.stops[2] }
            GradientStop { position: 1.0; color: ring.stops[3] }
        }
        PathRectangle {
            x: ring.a * frame.u; y: ring.a * frame.u
            width: frame.width - 2 * ring.a * frame.u; height: frame.height - 2 * ring.a * frame.u
            radius: Math.max(0, frame.outerR - ring.a * frame.u)
        }
        PathRectangle {
            x: ring.b * frame.u; y: ring.b * frame.u
            width: frame.width - 2 * ring.b * frame.u; height: frame.height - 2 * ring.b * frame.u
            radius: Math.max(0, frame.outerR - ring.b * frame.u)
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Ring { a: 0; b: 1; stops: ["#a9a49c", "#8f8a83", "#7c7871", "#5b5852"] }
        Ring { a: 1; b: 10; stops: ["#fbfaf7", "#dcd8d1", "#c2beb7", "#9a958f"] }
        Ring { a: 2.5; b: 3.5; stops: ["#ffffff", "#f6f4f0", "#e4e1dc", "#c7c3bd"] }
        Ring { a: 10; b: 12; stops: ["#6e6a63", "#5f5b55", "#57534d", "#45423d"] }
    }
}
