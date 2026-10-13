import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services

// A card that rises 8 px out of the bar and fades in (180 ms, `place`).
// Nothing drops from the top except notifications (section 10).
//   side: "left" | "center" | "right" | "middle" (vertically centred, e.g. launcher)
PanelWindow {
    id: win

    property string name: ""
    property string side: "right"
    property int offset: Theme.margin           // distance from the screen edge
    property bool exclusiveKeys: false
    readonly property bool shown: Panels.open === name
    default property alias content: holder.data
    readonly property int pad: 24                // room for the card's shadow
    readonly property int padBottom: 12

    signal opened()

    anchors.bottom: side !== "middle"
    anchors.left: side === "left"
    anchors.right: side === "right"
    margins.bottom: 0
    margins.left: side === "left" ? offset - pad : 0
    margins.right: side === "right" ? offset - pad : 0

    implicitWidth: holder.childrenRect.width + 2 * pad
    implicitHeight: holder.childrenRect.height + pad + padBottom
    color: "transparent"
    visible: shown || holder.opacity > 0.01

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "archive-popup"
    WlrLayershell.keyboardFocus: shown ? (exclusiveKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
                                       : WlrKeyboardFocus.None

    onShownChanged: if (shown) opened()

    Item {
        id: holder
        x: win.pad
        y: win.pad + (win.shown ? 0 : Theme.popupRise)
        width: childrenRect.width
        height: childrenRect.height
        opacity: win.shown ? 1 : 0

        Behavior on y { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: win.shown ? Theme.place : Theme.lift } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: win.shown ? Theme.place : Theme.lift } }
    }

    // Click anywhere else (or press Escape in the card) to put it away.
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (Panels.open === win.name) Panels.close()
    }
}
