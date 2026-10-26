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
    // above the bar: the card takes no room from windows (Ignore), so it
    // does not get pushed clear of the bar's zone either
    margins.bottom: side === "middle" ? 0 : Theme.barHeight
    margins.left: side === "left" ? offset - pad : 0
    margins.right: side === "right" ? offset - pad : 0

    exclusionMode: ExclusionMode.Ignore         // lies over the desk; takes no room from windows
    implicitWidth: holder.childrenRect.width + 2 * pad
    implicitHeight: holder.childrenRect.height + pad + padBottom
    color: "transparent"
    // drawn once, unseen, before it moves: while it is being prepared
    // (Panels.ready), and again as it opens, so that its rise is not spent
    // on the frame that makes it
    readonly property bool warming: Panels.preparing === name || (shown && !begun)
    property bool begun: false
    property bool counting: false       // (frames drawn before it opened do not count)
    readonly property bool up: shown && begun
    visible: shown || holder.opacity > 0.01 || warming

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "archive-popup"
    WlrLayershell.keyboardFocus: shown ? (exclusiveKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)
                                       : WlrKeyboardFocus.None

    onShownChanged: {
        begun = holder.opacity > 0.01;  // (still on screen, closing: on at once)
        counting = false;
        Qt.callLater(() => { win.counting = true; });
        if (shown) opened();
        else grabArmed = false;
    }

    Item {
        id: holder
        x: win.pad
        y: win.pad + (win.up ? 0 : Theme.popupRise)
        width: childrenRect.width
        height: childrenRect.height
        opacity: win.up ? 1 : win.warming ? (win.shown ? 0.004 : 0.003) : 0
        Connections {
            target: win.warming ? holder.Window.window : null
            function onFrameSwapped() { if (!win.shown) Panels.drawn(win.name); else if (win.counting) win.begun = true; }
        }
        Timer { interval: 400; running: win.shown && !win.begun; onTriggered: win.begun = true }

        Behavior on y { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: win.shown ? Theme.place : Theme.lift } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: win.shown ? Theme.place : Theme.lift } }
    }

    // Click anywhere else (or press Escape in the card) to put it away.
    // The grab starts a moment after the card is on screen: started in the
    // same instant, before the surface is mapped, it can fail silently and
    // the card then never closes on an outside click.
    property bool grabArmed: false
    Timer {
        interval: 80
        running: win.shown && !win.grabArmed
        onTriggered: win.grabArmed = true
    }
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown && win.grabArmed
        onCleared: if (Panels.open === win.name) Panels.close()
    }
}
