import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components

// The power button (archive-boot power hands it to the desktop). Held, a
// card appears and its ruler fills while you keep holding; when it is full
// the archive closes (shuts down). Let go before then and nothing happens.
// A quick press opens Disposition with Shut down asked; a second press
// says yes (Disposition.qml). Many laptops report a press and its let-go
// at the same instant however long the button is held: there, only the
// quick press is ever seen.
//
// The timing is Hyprland's (binds.lua), which sees the press and the
// let-go in order and shuts down only if the button is still down at the
// end; this card only shows it.
PanelWindow {
    id: win

    readonly property int pad: 24

    property bool shown: false
    property bool closing: false
    property real fill: 0

    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 380 + 2 * pad
    implicitHeight: card.height + 2 * pad
    color: "transparent"
    visible: shown || holder.opacity > 0.01
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-power"

    // still held: fill the ruler over the time left (ms)
    function show(ms: int): void {
        closing = false;
        shown = true;
        filling.duration = Math.max(1, ms);
        filling.restart();
    }
    // let go too soon
    function cancel(): void {
        filling.stop();
        shown = false;
        fill = 0;
    }
    function close(): void {
        filling.stop();
        fill = 1;
        closing = true;
        shown = true;
    }

    NumberAnimation { id: filling; target: win; property: "fill"; from: 0; to: 1 }

    Item {
        id: holder
        x: win.pad
        y: win.pad + (win.shown ? 0 : Theme.popupRise)
        width: card.width
        height: card.height
        opacity: win.shown ? 1 : 0
        Behavior on y { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: win.shown ? Theme.place : Theme.lift } }
        Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.durPopup : Theme.durWindowOut } }

        IndexCard {
            id: card
            width: 380
            title: win.closing ? "Closing the archive." : "Shut down"
            subtitle: win.closing ? "" : "Keep holding the power button."
            seed: 909
            lift: 1.6

            Item {
                width: parent.width
                height: 50
                RulerSlider {
                    x: Theme.headerPadH + 4
                    width: parent.width - 2 * (Theme.headerPadH + 4)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    interactive: false
                    numbered: false
                    eased: false
                    value: win.fill
                }
            }
        }
    }
}
