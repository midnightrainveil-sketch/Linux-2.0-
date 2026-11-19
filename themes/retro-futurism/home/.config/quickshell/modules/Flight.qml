import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The launcher's lifter, lowering a launched app's cartridge into the
// taskbar's port (services/Cartridges.qml: eject() starts it, land() when it
// is in). The bar has slid across so its port is under the launcher's slot;
// two rods run down from the slot's clamp, a yoke on the cartridge, and
// lower it straight down, a little smaller as it goes (the port's size), into
// the port; then the yoke lets go and the rods snap back up.
// Over everything, letting every click through, there only while it works.
PanelWindow {
    id: lifter

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-flight"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}                                // nothing here takes the pointer
    visible: Cartridges.flying || back.running

    // the cartridge: its middle, its scale
    property real cx: 0
    property real cy: 0
    property real cs: 1
    property bool holding: true                    // the cartridge still on the yoke
    // where the rods end (their foot: the yoke)
    property real foot: 0
    readonly property real seatY: Cartridges.portY - (425 - 222.5) * Cartridges.portS
    readonly property real halfW: 350 * cs / 2
    readonly property real yokeY: cy - 445 * cs / 2 - 6 * cs / 0.3   // just over the cartridge's top

    Cartridge {
        visible: lifter.holding
        entry: Cartridges.flyEntry
        x: lifter.cx - width / 2
        y: lifter.cy - height / 2
        scale: lifter.cs
        transformOrigin: Item.Center
    }

    // the rods, from the clamp to the yoke
    component Rod: Rectangle {
        width: Math.max(4, 22 * lifter.cs)
        y: Cartridges.liftTop
        height: Math.max(0, lifter.foot - Cartridges.liftTop)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#6c6862" }
            GradientStop { position: 0.35; color: "#fbfaf7" }
            GradientStop { position: 0.7; color: "#c3beb5" }
            GradientStop { position: 1.0; color: "#57534d" }
        }
    }
    Rod { x: lifter.cx - lifter.halfW + 10 * lifter.cs - width / 2 }
    Rod { x: lifter.cx + lifter.halfW - 10 * lifter.cs - width / 2 }
    // the yoke: a cream bar across, bolts at its ends, the clamp's red mark
    Rectangle {
        x: lifter.cx - lifter.halfW - 6 * lifter.cs / 0.3
        width: 2 * lifter.halfW + 12 * lifter.cs / 0.3
        y: lifter.foot - height / 2
        height: Math.max(6, 34 * lifter.cs)
        radius: height * 0.3
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f4ebdc" }
            GradientStop { position: 0.6; color: "#e3d5bf" }
            GradientStop { position: 1.0; color: "#b8a88e" }
        }
        border.width: 1; border.color: "#8d7f68"
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.18; height: parent.height * 0.26; radius: height / 2; color: "#c4462a" }
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: index === 0 ? parent.height * 0.35 : parent.width - parent.height * 0.35 - width
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.42; height: width; radius: width / 2
                color: "#a39886"; border.width: 1; border.color: "#5d5547"
            }
        }
    }

    // down, in
    SequentialAnimation {
        id: down
        ScriptAction {
            script: {
                lifter.holding = true;
                lifter.cx = Cartridges.fromX; lifter.cy = Cartridges.fromY; lifter.cs = Cartridges.fromS;
                lifter.foot = lifter.yokeY;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: lifter; property: "cx"; to: Cartridges.portX; duration: 420; easing.type: Easing.InOutCubic }
            NumberAnimation { target: lifter; property: "cy"; to: lifter.seatY; duration: 420; easing.type: Easing.InOutCubic }
            NumberAnimation { target: lifter; property: "cs"; to: Cartridges.portS; duration: 420; easing.type: Easing.InOutCubic }
        }
        // a click as it seats
        NumberAnimation { target: lifter; property: "cy"; to: lifter.seatY + 3; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: lifter; property: "cy"; to: lifter.seatY; duration: 70; easing.type: Easing.OutQuad }
        ScriptAction { script: { lifter.holding = false; Cartridges.land(); back.restart(); } }
    }
    // and the rods back up, quickly
    NumberAnimation { id: back; target: lifter; property: "foot"; to: Cartridges.liftTop; duration: 190; easing.type: Easing.InCubic }
    // the yoke rides on the cartridge while it is held
    Binding { target: lifter; property: "foot"; value: lifter.yokeY; when: down.running && lifter.holding }

    Connections {
        target: Cartridges
        function onFlyingChanged() { if (Cartridges.flying) down.restart(); }
    }
}
