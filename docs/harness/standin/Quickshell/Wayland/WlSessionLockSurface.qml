import QtQuick
import QtQuick.Window
Window {
    property string _layer: "Lock"
    readonly property var _edges: [true, true, true, true]
    readonly property var _margins: [0, 0, 0, 0]
    flags: Qt.FramelessWindowHint
    width: harness.screenW
    height: harness.screenH
    property bool _visible: false
    objectName: "panel"
}
