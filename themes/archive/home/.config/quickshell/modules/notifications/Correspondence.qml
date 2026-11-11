import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Correspondence: notifications arrive top-right, above the record column,
// 360 px wide. The only thing that ever drops from the top of the screen.
// The window spans the screen while letters are showing (only they take the
// pointer), so one can be carried and flung anywhere (Letter.qml): a window
// that grew under a held letter would throw it across the screen.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Notifs.popups.count > 0
    mask: Region { item: stack }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-correspondence"

    Column {
        id: stack
        x: win.width - Theme.margin - width
        y: Theme.margin
        width: 360
        spacing: 16

        Repeater {
            model: Notifs.popups
            Letter {}
        }
    }
}
