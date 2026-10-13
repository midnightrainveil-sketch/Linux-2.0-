import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// Instrument reading (volume / brightness OSD): bottom-centre, just above the
// bar. A small card with the ruler slider and "VOLUME  No. 45".
PanelWindow {
    id: win

    readonly property int pad: 24
    property string kind: "volume"
    property bool shown: false

    anchors.bottom: true
    implicitWidth: 340 + 2 * pad
    implicitHeight: card.height + pad + 12
    color: "transparent"
    visible: shown || holder.opacity > 0.01
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-osd"

    readonly property real value: kind === "brightness" ? Brightness.percent / 100 : Audio.volume
    readonly property string word: kind === "brightness" ? "Light" : (Audio.muted ? "Volume, muted" : "Volume")
    readonly property int number: kind === "brightness" ? Brightness.percent : Audio.percent

    function show(k) {
        kind = k;
        shown = true;
        hide.restart();
    }

    Connections { target: Audio; function onChanged() { win.show("volume"); } }
    Connections { target: Brightness; function onChanged() { win.show("brightness"); } }
    Connections { target: Panels; function onOsdSerialChanged() { win.show(Panels.osdKind); } }

    Timer { id: hide; interval: 1400; onTriggered: win.shown = false }

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
            width: 340
            title: win.word
            number: String(win.number)
            seed: 808
            lift: 1.4

            Item {
                width: parent.width
                height: 50
                RulerSlider {
                    x: Theme.headerPadH + 4
                    width: parent.width - 2 * (Theme.headerPadH + 4)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    interactive: false
                    value: win.value
                }
            }
        }
    }
}
