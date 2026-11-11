import QtQuick
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services

// The lamp's light on one screen (see services/Lamp.qml): a warm pool where
// the pointer last crossed the desk, and a little more dark everywhere else.
// Night only; nothing takes input here.
Item {
    id: root

    required property string screenName
    readonly property real strength: (Lamp.isOn ? Theme.night : 0) * (lit ? 1 : 0)
    readonly property bool lit: Lamp.atX >= 0 && (Lamp.onScreen === "" || Lamp.onScreen === screenName)

    // the lamp is carried, not teleported: it glides after the pointer
    property real lx: Lamp.atX >= 0 ? Lamp.atX : width * 0.3
    property real ly: Lamp.atY >= 0 ? Lamp.atY : height * 0.4
    Behavior on lx { SmoothedAnimation { velocity: 1400; reversingMode: SmoothedAnimation.Sync } }
    Behavior on ly { SmoothedAnimation { velocity: 1400; reversingMode: SmoothedAnimation.Sync } }

    opacity: strength
    visible: opacity > 0.005
    Behavior on opacity { NumberAnimation { duration: Theme.dur(600) } }

    // the room around the pool
    RadialGradient {
        x: root.lx - width / 2
        y: root.ly - height / 2
        width: Math.max(root.width, root.height) * 2.6
        height: width
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.11; color: "transparent" }
            GradientStop { position: 0.30; color: Qt.rgba(0.01, 0.03, 0.07, 0.30) }
            GradientStop { position: 0.5; color: Qt.rgba(0.01, 0.03, 0.07, 0.48) }
        }
    }

    // the pool of light: warm, brightest in the middle, soft at the rim
    RadialGradient {
        x: root.lx - width / 2
        y: root.ly - height / 2
        width: 900
        height: 900
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1.0, 0.86, 0.62, 0.25) }
            GradientStop { position: 0.22; color: Qt.rgba(1.0, 0.84, 0.60, 0.16) }
            GradientStop { position: 0.38; color: Qt.rgba(1.0, 0.82, 0.58, 0.05) }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }
}
