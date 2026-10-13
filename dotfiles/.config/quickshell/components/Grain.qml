import QtQuick
import qs.theme

// Tiled 512 px fibre texture. Dark fibres read as "multiply" on light paper;
// at night a light layer is added so the cyanotype brush marks show.
Item {
    id: root
    clip: true

    property real strength: 1.0

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/grain-dark.png")
        fillMode: Image.Tile
        opacity: Theme.grainDark * root.strength
        smooth: false
        asynchronous: true
    }
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/grain-light.png")
        fillMode: Image.Tile
        opacity: Theme.grainLight * root.strength
        visible: opacity > 0.002
        smooth: false
        asynchronous: true
    }
}
