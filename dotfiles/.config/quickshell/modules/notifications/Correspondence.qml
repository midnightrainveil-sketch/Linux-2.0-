import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Correspondence: notifications arrive top-right, above the record column,
// 360 px wide. The only thing that ever drops from the top of the screen.
PanelWindow {
    id: win

    readonly property int pad: 24
    anchors { top: true; right: true }
    margins.top: Theme.margin - pad
    margins.right: Theme.margin - pad
    implicitWidth: 360 + 2 * pad
    implicitHeight: Math.max(1, stack.height + 2 * pad)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Notifs.popups.count > 0
    mask: Region { item: stack }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-correspondence"

    Column {
        id: stack
        x: win.pad
        y: win.pad
        width: 360
        spacing: 16

        Repeater {
            model: Notifs.popups
            Letter {}
        }
    }
}
