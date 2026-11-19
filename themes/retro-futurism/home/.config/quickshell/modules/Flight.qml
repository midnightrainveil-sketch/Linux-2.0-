import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// A launched app's cartridge on its way from the launcher's slot to the
// taskbar's port (services/Cartridges.qml: eject() starts it, land() ends
// it). Over everything, letting every click through, there only while one
// flies: it arcs down to just above the port, turning a little as it goes,
// then drops in.
PanelWindow {
    id: flight

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-flight"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}                                // nothing here takes the pointer
    visible: Cartridges.flying

    // where it is: its middle, its scale, its turn
    property real cx: 0
    property real cy: 0
    property real cs: 1
    property real turn: 0
    // seated: its middle above the port's foot (the cartridge is 445 tall,
    // its contacts' foot at 425)
    readonly property real seatY: Cartridges.portY - (425 - 222.5) * Cartridges.portS

    Cartridge {
        entry: Cartridges.flyEntry
        x: flight.cx - width / 2
        y: flight.cy - height / 2
        scale: flight.cs
        rotation: flight.turn
        transformOrigin: Item.Center
    }

    SequentialAnimation {
        id: fly
        ScriptAction {
            script: {
                flight.cx = Cartridges.fromX; flight.cy = Cartridges.fromY;
                flight.cs = Cartridges.fromS; flight.turn = 0;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: flight; property: "cx"; to: Cartridges.portX; duration: 560; easing.type: Easing.InOutCubic }
            // up a little first, then down: an arc
            SequentialAnimation {
                NumberAnimation { target: flight; property: "cy"; to: Cartridges.fromY - 30; duration: 140; easing.type: Easing.OutQuad }
                NumberAnimation { target: flight; property: "cy"; to: flight.seatY - 46; duration: 420; easing.type: Easing.InOutCubic }
            }
            NumberAnimation { target: flight; property: "cs"; to: Cartridges.portS; duration: 560; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                NumberAnimation { target: flight; property: "turn"; to: -9; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: flight; property: "turn"; to: 0; duration: 300; easing.type: Easing.InOutQuad }
            }
        }
        // and in
        NumberAnimation { target: flight; property: "cy"; to: flight.seatY; duration: 130; easing.type: Easing.InQuad }
        ScriptAction { script: Cartridges.land() }
    }
    Connections {
        target: Cartridges
        function onFlyingChanged() { if (Cartridges.flying) fly.restart(); }
    }
}
