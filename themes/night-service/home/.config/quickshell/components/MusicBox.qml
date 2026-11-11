import QtQuick
import qs.theme

// The music box (Compartment 19's audio card, in place of the cassette):
// the picture (assets/flavours/<theme>/musicbox.png). While music plays a
// soft light runs along its brass cylinder, as it turns, and a few small
// ink notes drift up out of it.
Item {
    id: root
    property url source
    property bool playing: false

    implicitWidth: 140
    implicitHeight: 142

    Image {
        id: box
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }

    // the light along the turning cylinder (where it lies in the picture)
    Item {
        x: root.width * 0.37; y: root.height * 0.47
        width: root.width * 0.37; height: root.height * 0.085
        clip: true
        visible: root.playing
        Rectangle {
            id: glint
            width: parent.width * 0.22
            height: parent.height
            rotation: 12
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 0.95, 0.8, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 0.95, 0.8, 0.45) }
                GradientStop { position: 1; color: Qt.rgba(1, 0.95, 0.8, 0) }
            }
            NumberAnimation on x {
                running: root.playing && root.visible
                loops: Animation.Infinite
                from: -glint.width; to: glint.parent.width
                duration: 1700
            }
        }
    }

    // notes drifting up out of the open box
    Repeater {
        model: 4
        Text {
            required property int index
            readonly property real phase: index / 4
            property real t: 0
            text: index % 2 ? "♪" : "♫"
            font.pixelSize: 13 + (index % 2) * 3
            color: Theme.soft
            visible: root.playing
            x: root.width * (0.46 + 0.16 * Math.sin((t + phase) * 6.3) + 0.1 * (index - 1.5) / 1.5)
            y: root.height * 0.4 - root.height * 0.55 * ((t + phase) % 1)
            opacity: 0.85 * Math.sin(Math.PI * ((t + phase) % 1))
            NumberAnimation on t {
                running: root.playing && root.visible
                loops: Animation.Infinite
                from: 0; to: 1
                duration: 3600
            }
        }
    }
}
