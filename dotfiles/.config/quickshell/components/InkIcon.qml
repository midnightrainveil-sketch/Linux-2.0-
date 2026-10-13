import QtQuick
import Qt5Compat.GraphicalEffects
import qs.theme

// A margin sketch icon (section 9). SVGs live in assets/icons (or
// assets/weather) and are drawn in any ink colour: line icons default to
// ink.graphite; `fill` parts of an icon keep their own alpha, so state fills
// and pencil shading survive the recolouring.
Item {
    id: root

    property string name: ""
    property string group: "icons"
    property color color: Theme.graphite
    property int size: 18

    implicitWidth: size
    implicitHeight: size

    // Your own artwork wins: assets/<group>/<name>.png is used when present,
    // the generated .svg placeholder otherwise.
    property bool usePng: true
    onNameChanged: usePng = true

    Image {
        id: img
        anchors.fill: parent
        source: root.name === "" ? "" : Qt.resolvedUrl("../assets/" + root.group + "/" + root.name + (root.usePng ? ".png" : ".svg"))
        onStatusChanged: if (status === Image.Error && root.usePng) root.usePng = false
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
        smooth: true
        mipmap: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: img
        source: img
        color: root.color
        cached: false
    }
}
