import QtQuick
import QtQuick.Window

// A layer surface, as an ordinary window the harness grabs and places.
Window {
    id: w
    property Edges anchors: Edges {}
    property Margins margins: Margins {}
    readonly property var _edges: [anchors.top, anchors.bottom, anchors.left, anchors.right]
    readonly property var _margins: [margins.top, margins.bottom, margins.left, margins.right]
    property real implicitWidth: 0
    property real implicitHeight: 0
    property real exclusiveZone: 0
    property int exclusionMode: 0
    property var mask
    property string _layer: "Top"
    property string _namespace: ""
    property bool _keys: false
    flags: Qt.FramelessWindowHint
    width: anchors.left && anchors.right ? harness.screenW - margins.left - margins.right : Math.max(1, implicitWidth)
    height: anchors.top && anchors.bottom ? harness.screenH - margins.top - margins.bottom : Math.max(1, implicitHeight)
    property bool _visible: true
    objectName: "panel"
}
