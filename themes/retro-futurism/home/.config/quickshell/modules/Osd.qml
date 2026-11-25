import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The volume or the brightness, shown as it changes (the keys, a player, the
// control deck's faders aside): an LED ladder behind smoked glass, in the
// windows' own chrome rim (the taskbar's pieces, as the chromerim plugin and
// ChromePanel lay them), at an edge of the screen as the cassette player's
// meter. The volume: amber, at the right edge. The brightness: blue, at the
// left. It slides in from its edge, lights to the level, and goes after a
// moment. A muted sound: the ladder dark, "--" below.
//
//   Osd { kind: "volume" }       Osd { kind: "brightness" }
PanelWindow {
    id: win

    property string kind: "volume"                  // volume, brightness
    readonly property bool onLeft: kind === "brightness"

    anchors { right: !win.onLeft; left: win.onLeft }
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

    readonly property int value: kind === "volume" ? Audio.percent : Brightness.percent
    readonly property bool muted: kind === "volume" && Audio.muted
    readonly property int lit: muted ? 0 : Math.round(Math.min(100, value) * 16 / 100)

    // the LEDs' colours, neon: the tube's colour, its white-hot core, the
    // top three hotter (a deeper tube), unlit, and the glow round them
    readonly property color ledOn: kind === "volume" ? "#ff9a1a" : "#2f8cff"
    readonly property color coreOn: kind === "volume" ? "#fff4d8" : "#eaf6ff"
    readonly property color ledTop: kind === "volume" ? "#ff4a26" : "#2bc4ff"
    readonly property color coreTop: kind === "volume" ? "#ffe4d6" : "#f0fcff"
    readonly property color ledOff: kind === "volume" ? "#33261a" : "#18263a"
    readonly property color glow: kind === "volume" ? "#ff8a1f" : "#2f8cff"

    property bool shown: false
    property real p: shown ? 1 : 0
    Behavior on p { NumberAnimation { duration: win.shown ? 260 : 220; easing.type: win.shown ? Easing.OutCubic : Easing.InCubic } }

    function show(): void {
        // (not while the control deck is up: its faders show it already)
        if (Widgets.current === "controls" || Scene.locked) return;
        shown = true;
        hold.restart();
    }
    Timer { id: hold; interval: 1400; onTriggered: win.shown = false }
    Connections { target: Audio; enabled: win.kind === "volume"; function onChanged() { win.show(); } }
    Connections { target: Brightness; enabled: win.kind === "brightness"; function onChanged() { win.show(); } }

    Item {
        id: body
        width: 120; height: 440
        // in from its own edge
        x: win.onLeft ? 60 - (1 - win.p) * (width + 60) : (1 - win.p) * (width + 60)
        y: 0

        // ---- the chrome rim: the windows' own pieces, corners four rims
        // deep, the straights stretched between
        readonly property real rim: 14
        readonly property real k: 4 * rim
        readonly property real innerR: 17
        readonly property string dir: Settings.art + "/rim/"

        // the smoked glass, inside the rim
        Rectangle {
            x: body.rim - 1; y: body.rim - 1
            width: body.width - 2 * (body.rim - 1); height: body.height - 2 * (body.rim - 1)
            radius: body.innerR
            color: "#1b1917"
            Rectangle {      // the rim's shadow on the glass, along its top
                width: parent.width; height: 22; radius: body.innerR
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
                }
            }
        }

        component Piece: Image { smooth: true; mipmap: true; fillMode: Image.Stretch }
        Piece { id: tl; source: body.dir + "corner-tl.png"; width: body.k; height: body.k }
        Piece { x: body.width - body.k; source: body.dir + "corner-tr.png"; width: body.k; height: body.k }
        Piece { y: body.height - body.k; source: body.dir + "corner-bl.png"; width: body.k; height: body.k }
        Piece { x: body.width - body.k; y: body.height - body.k; source: body.dir + "corner-br.png"; width: body.k; height: body.k }
        Piece { x: body.k; width: body.width - 2 * body.k; height: body.rim; source: body.dir + "top.png" }
        Piece { x: body.k; y: body.height - body.rim; width: body.width - 2 * body.k; height: body.rim; source: body.dir + "bottom.png" }
        Piece { y: body.k; width: body.rim; height: body.height - 2 * body.k; source: body.dir + "left.png" }
        Piece { x: body.width - body.rim; y: body.k; width: body.rim; height: body.height - 2 * body.k; source: body.dir + "right.png" }
        // (no pieces: the rim drawn)
        Frame {
            anchors.fill: parent
            visible: tl.status !== Image.Ready
            rim: body.rim
            innerR: body.innerR
        }

        // the LEDs and the number, glowing
        Item {
            anchors.fill: parent
            layer.enabled: win.visible
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: win.glow; shadowBlur: 1.0; shadowOpacity: 1.0
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 32
            }
            Column {
                x: 30; y: 34; spacing: 6
                Repeater {
                    model: 16
                    Item {
                        id: led
                        required property int index
                        readonly property bool on: (15 - index) < win.lit
                        readonly property color tube: index < 3 ? win.ledTop : win.ledOn
                        readonly property color core: index < 3 ? win.coreTop : win.coreOn
                        width: 60; height: 13
                        // its halo (drawn, so it shows even where the glow is not)
                        Rectangle {
                            anchors.centerIn: parent; width: parent.width + 12; height: parent.height + 9; radius: 8
                            color: led.tube; opacity: led.on ? 0.22 : 0
                            Behavior on opacity { NumberAnimation { duration: 70 } }
                        }
                        Rectangle {
                            anchors.centerIn: parent; width: parent.width + 5; height: parent.height + 4; radius: 5
                            color: led.tube; opacity: led.on ? 0.40 : 0
                            Behavior on opacity { NumberAnimation { duration: 70 } }
                        }
                        // the tube
                        Rectangle {
                            anchors.fill: parent; radius: 3
                            color: led.on ? led.tube : win.ledOff
                            Behavior on color { ColorAnimation { duration: 70 } }
                        }
                        // its white-hot core
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 3; radius: 2
                            color: led.core; opacity: led.on ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 70 } }
                        }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: 344
                text: win.muted ? "--" : String(win.value).padStart(2, "0")
                color: win.coreOn
                style: Text.Outline; styleColor: win.ledOn
                font.family: "VT323"; font.pixelSize: 54
            }
        }
        // what it is: a speaker (struck through when muted), or a sun
        Canvas {
            x: 44; y: 392; width: 32; height: 32
            property string what: win.kind
            property bool off: win.muted
            onWhatChanged: requestPaint()
            onOffChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset();
                const s = width / 24; c.scale(s, s);
                c.strokeStyle = "#8a8378"; c.fillStyle = "#8a8378"; c.lineWidth = 2; c.lineCap = "round"; c.lineJoin = "round";
                if (what === "volume") {
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
