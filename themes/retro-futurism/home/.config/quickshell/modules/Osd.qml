import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services

// The volume and brightness, shown as they change (the keys, a player, the
// control deck's faders aside): an amber LED ladder behind smoked glass, in
// a chrome rim, at the right edge of the screen, as the cassette player's
// meter. It slides in from the edge, lights to the level, and goes after a
// moment. A muted sound: the ladder dark, "--" below.
PanelWindow {
    id: win

    anchors { right: true }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 120 + 60
    implicitHeight: 440
    color: "transparent"
    visible: p > 0.001
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // (it takes no pointer: clicks go to what is under it)
    mask: Region {}

    property string what: "volume"          // volume, brightness
    readonly property int value: what === "volume" ? Audio.percent : Brightness.percent
    readonly property bool muted: what === "volume" && Audio.muted
    readonly property int lit: muted ? 0 : Math.round(Math.min(100, value) * 16 / 100)

    property bool shown: false
    property real p: shown ? 1 : 0
    Behavior on p { NumberAnimation { duration: win.shown ? 260 : 220; easing.type: win.shown ? Easing.OutCubic : Easing.InCubic } }

    function show(kind: string): void {
        // (not while the control deck is up: its faders show it already)
        if (Widgets.current === "controls" || Scene.locked) return;
        what = kind;
        shown = true;
        hold.restart();
    }
    Timer { id: hold; interval: 1400; onTriggered: win.shown = false }
    Connections { target: Audio; function onChanged() { win.show("volume"); } }
    Connections { target: Brightness; function onChanged() { win.show("brightness"); } }

    Item {
        id: body
        width: 120; height: 440
        x: (1 - win.p) * (width + 60)
        y: 0

        // the chrome rim
        Rectangle {
            anchors.fill: parent; radius: 22
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f1eee8" }
                GradientStop { position: 0.18; color: "#c9c6bf" }
                GradientStop { position: 0.5; color: "#8f8c85" }
                GradientStop { position: 0.82; color: "#cfccc5" }
                GradientStop { position: 1.0; color: "#e8e5de" }
            }
            border.width: 1; border.color: "#57544e"
            Rectangle {
                anchors.fill: parent; anchors.margins: 3; radius: 19
                color: "transparent"; border.width: 1.5; border.color: "#fbf9f4"; opacity: 0.7
            }
        }
        // the smoked glass
        Rectangle {
            x: 10; y: 10; width: parent.width - 20; height: parent.height - 20; radius: 14
            color: "#1b1917"
            border.width: 2; border.color: "#0b0a09"
        }
        // the LEDs and the number, glowing
        Item {
            anchors.fill: parent
            layer.enabled: win.visible
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#ff8a1f"; shadowBlur: 0.7; shadowOpacity: 0.85
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 24
            }
            Column {
                x: 30; y: 34; spacing: 6
                Repeater {
                    model: 16
                    Rectangle {
                        required property int index
                        readonly property bool on: (15 - index) < win.lit
                        width: 60; height: 13; radius: 2
                        color: on ? (index < 3 ? "#ff6a3a" : "#ffb444") : "#3a2c1e"
                        Behavior on color { ColorAnimation { duration: 70 } }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: 350
                text: win.muted ? "--" : String(win.value).padStart(2, "0")
                color: "#ffb444"
                font.family: "VT323"; font.pixelSize: 54
            }
        }
        // what it is: a speaker (struck through when muted), or a sun
        Canvas {
            id: glyph
            x: 44; y: 400; width: 32; height: 32
            property string kind: win.what
            property bool off: win.muted
            onKindChanged: requestPaint()
            onOffChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset();
                const s = width / 24; c.scale(s, s);
                c.strokeStyle = "#8a8378"; c.fillStyle = "#8a8378"; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round";
                if (kind === "volume") {
                    c.beginPath(); c.moveTo(3, 9); c.lineTo(7, 9); c.lineTo(12, 4.5); c.lineTo(12, 19.5); c.lineTo(7, 15); c.lineTo(3, 15); c.closePath(); c.fill();
                    if (off) { c.beginPath(); c.moveTo(15, 9); c.lineTo(21, 15); c.moveTo(21, 9); c.lineTo(15, 15); c.stroke(); }
                    else {
                        c.beginPath(); c.arc(12, 12, 5, -0.8, 0.8); c.stroke();
                        c.beginPath(); c.arc(12, 12, 9, -0.8, 0.8); c.stroke();
                    }
                } else {
                    c.beginPath(); c.arc(12, 12, 4.2, 0, Math.PI * 2); c.fill();
                    for (let i = 0; i < 8; i++) {
                        const a = i * Math.PI / 4;
                        c.beginPath(); c.moveTo(12 + Math.cos(a) * 7, 12 + Math.sin(a) * 7); c.lineTo(12 + Math.cos(a) * 10, 12 + Math.sin(a) * 10); c.stroke();
                    }
                }
            }
        }
    }
}
