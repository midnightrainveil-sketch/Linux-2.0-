import QtQuick
import qs.services

// A small panel that floats over the desk: the windows' chrome rim round it
// (the taskbar's own, cut from its picture by tools/make_rim.py, as the
// chromerim plugin lays it round windows) and inside, an e-ink screen like
// the control deck's. Its children go on the screen, inside the rim.
//
//   ChromePanel { width: 640; height: 560; Text { ... } }
Item {
    id: panel

    property real rim: 17                       // as the windows' (Theme.frameRim)
    readonly property real innerR: 21           // as the windows' corners
    readonly property real pad: 18              // from the rim to what is on the screen
    readonly property string dir: Settings.art + "/rim/"
    default property alias content: screen.data

    // ---- the e-ink: the deck's glass, a light warm grey, a touch darker
    // towards its foot and its right, in the rim's shadow at the top
    Rectangle {
        x: panel.rim - 1; y: panel.rim - 1
        width: panel.width - 2 * (panel.rim - 1); height: panel.height - 2 * (panel.rim - 1)
        radius: panel.innerR
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#bdbcbb" }
            GradientStop { position: 0.55; color: "#bab9b8" }
            GradientStop { position: 1.0; color: "#b0afae" }
        }
        Rectangle {
            anchors.fill: parent; radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }
        // the rim's shadow on the glass, along its top
        Rectangle {
            width: parent.width; height: 26; radius: panel.innerR
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.1, 0.1, 0.1, 0.18) }
                GradientStop { position: 1.0; color: Qt.rgba(0.1, 0.1, 0.1, 0) }
            }
        }
    }

    // what is on the screen
    Item {
        id: screen
        x: panel.rim + panel.pad; y: panel.rim + panel.pad
        width: panel.width - 2 * (panel.rim + panel.pad)
        height: panel.height - 2 * (panel.rim + panel.pad)
    }

    // ---- the rim: corners four rims deep, the straights stretched between
    readonly property real k: 4 * rim
    component Piece: Image { smooth: true; mipmap: true; fillMode: Image.Stretch }
    Piece { id: tl; source: panel.dir + "corner-tl.png"; width: panel.k; height: panel.k }
    Piece { x: panel.width - panel.k; source: panel.dir + "corner-tr.png"; width: panel.k; height: panel.k }
    Piece { y: panel.height - panel.k; source: panel.dir + "corner-bl.png"; width: panel.k; height: panel.k }
    Piece { x: panel.width - panel.k; y: panel.height - panel.k; source: panel.dir + "corner-br.png"; width: panel.k; height: panel.k }
    Piece { x: panel.k; width: panel.width - 2 * panel.k; height: panel.rim; source: panel.dir + "top.png" }
    Piece { x: panel.k; y: panel.height - panel.rim; width: panel.width - 2 * panel.k; height: panel.rim; source: panel.dir + "bottom.png" }
    Piece { y: panel.k; width: panel.rim; height: panel.height - 2 * panel.k; source: panel.dir + "left.png" }
    Piece { x: panel.width - panel.rim; y: panel.k; width: panel.rim; height: panel.height - 2 * panel.k; source: panel.dir + "right.png" }
    // (no pieces: the rim drawn)
    Frame {
        anchors.fill: parent
        visible: tl.status !== Image.Ready
        rim: panel.rim
        innerR: panel.innerR
    }
}
