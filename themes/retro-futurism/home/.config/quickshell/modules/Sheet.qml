import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// A panel in the middle of the screen, over everything, with the keyboard:
// the themes list. A click beside it, or Escape,
// closes it.
PanelWindow {
    id: win

    property string name: ""
    property string title: ""
    property int panelWidth: 720
    readonly property bool shown: Panels.open === name
    default property alias content: holder.data
    readonly property alias panel: box
    signal opened()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-sheet"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown

    onShownChanged: if (shown) opened()
    Component.onCompleted: if (shown) opened()      // (built already open: shell.qml)

    Rectangle { anchors.fill: parent; color: "#140f0b"; opacity: 0.4 }
    MouseArea { anchors.fill: parent; onClicked: Panels.close() }

    Box {
        id: box
        title: win.title
        width: win.panelWidth
        height: headHeight + holder.childrenRect.height
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(Math.max(60, (win.height - height) * 0.4))
        color: Theme.panel
        radius: 14
        MouseArea { anchors.fill: parent }          // a click on the panel is not a click beside it
        Item { id: holder; width: parent.width; height: childrenRect.height }
    }
}
