import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.services

// The app launcher (art/AppLauncher.png): the Kairo cartridge launcher. Your
// apps are cartridges on its rail; the one in the centre slot is chosen.
// Super + Space, or the taskbar's port.
//
//   choosing   the wheel (mouse or touchpad), the arrow keys, Page Up / Down
//              (five at a time), Home / End, or a click on a cartridge
//   searching  just type: the rail keeps the apps that match (Backspace,
//              Esc clears; Esc again puts it away)
//   launching  Enter, or a click on the cartridge in the slot: the app
//              starts, its cartridge rises out of the slot and flies down
//              into the taskbar's port (modules/Flight.qml)
//
// Everything is placed in the mock-up's own pixels (body.png starts at its
// 24, 23; tools/make_launcher.py) and the whole launcher scaled once.
Widget {
    id: self
    widgetId: "launcher"

    readonly property real k: 0.72
    preferredWidth: 1534 * k
    preferredHeight: 941 * k

    // ---- what it holds
    property string query: ""
    readonly property var results: Apps.search(query)
    property int sel: 0
    // where the rail is (eased toward sel; a cartridge's offset is its index less this)
    property real pos: 0
    Behavior on pos { id: slide; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    readonly property var current: results.length > 0 ? results[Math.max(0, Math.min(sel, results.length - 1))] : null

    function choose(i: int): void {
        if (results.length === 0 || ejecting) return;
        sel = Math.max(0, Math.min(results.length - 1, i));
        pos = sel;
    }
    function move(d: int): void { choose(sel + d); }
    // launching: the app starts at once; its cartridge rises out of the
    // slot, then is let go (Cartridges.eject: modules/Flight.qml takes it to
    // the taskbar's port) and the launcher is put away
    property bool ejecting: false
    property real rise: 0                               // the slot's cartridge, up (mock-up px)
    property var ejected: null
    function launch(): void {
        if (!current || ejecting) return;
        ejecting = true;
        ejected = current;
        Apps.launch(current);
        ejectAnim.restart();
    }
    SequentialAnimation {
        id: ejectAnim
        NumberAnimation { target: self; property: "rise"; to: 95; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        ScriptAction { script: self.letGo() }
    }
    function letGo(): void {
        const c = slotCartridge();
        if (c) {
            const a = c.mapToItem(null, 0, 0), b = c.mapToItem(null, c.width, c.height);
            Cartridges.eject(ejected, (a.x + b.x) / 2, (a.y + b.y) / 2, (b.x - a.x) / 350);
        }
        letGoDone = true;
        close();
    }
    property bool letGoDone: false
    function slotCartridge(): var {
        for (let i = 0; i < rail.count; i++) {
            const p = rail.itemAt(i);
            if (p && p.ao < 0.5 && p.app !== null) return p.cartridge;
        }
        return null;
    }
    onQueryChanged: { slide.enabled = false; sel = 0; pos = 0; slide.enabled = true; }

    escapeHandler: () => { if (query !== "") { query = ""; return true; } return false; }
    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Left: case Qt.Key_Up: move(-1); break;
        case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab: move(1); break;
        case Qt.Key_PageUp: move(-5); break;
        case Qt.Key_PageDown: move(5); break;
        case Qt.Key_Home: choose(0); break;
        case Qt.Key_End: choose(results.length - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: launch(); break;
        case Qt.Key_Backspace: if (!ejecting) query = query.slice(0, -1); break;
        default:
            // anything printable searches
            if (!ejecting && e.text !== "" && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                if (query.length < 24) query += e.text;
                break;
            }
            return;
        }
        e.accepted = true;
    }

    // the wheel anywhere on it: a cartridge a notch (touchpads add up)
    property real wheelRest: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? -e.angleDelta.x : e.angleDelta.y;
            self.wheelRest += d;
            const steps = Math.trunc(self.wheelRest / 120);
            if (steps !== 0) { self.wheelRest -= steps * 120; self.move(-steps); }
        }
    }

    // ======================================================================
    // the launcher, in the mock-up's pixels
    Item {
        id: unit
        width: 1534; height: 941
        scale: self.k
        transformOrigin: Item.TopLeft
        function X(x) { return x - 24; }
        function Y(y) { return y - 23; }

        Image {
            anchors.fill: parent
            source: self.art("body.png")
            smooth: true; mipmap: true
        }

        // ---- the rail: seven places, each showing the app at its offset from
        // the slot; as the rail slides they move between the bays (the side
        // bays' middles 280, 510 | 1090, 1310; the slot's 784), a little
        // larger in the slot
        Repeater {
            id: rail
            model: 7
            Item {
                id: place
                property alias cartridge: cart
                required property int index
                readonly property int idx: Math.round(self.pos) + index - 3
                readonly property real o: idx - self.pos                    // its offset from the slot
                readonly property var app: idx >= 0 && idx < self.results.length ? self.results[idx] : null
                readonly property real ao: Math.abs(o)
                readonly property real cx: {
                    const P = [50, 280, 510, 784, 1090, 1310, 1540];       // offsets -3 .. 3
                    const f = Math.max(-3, Math.min(3, o)) + 3, i = Math.min(5, Math.floor(f));
                    return P[i] + (P[i + 1] - P[i]) * (f - i);
                }
                readonly property real s: 0.68 - 0.08 * Math.min(1, ao)
                readonly property real cy: 315 - 11 * Math.max(0, 1 - ao)       // the slot's sits higher
                visible: app !== null && ao < 2.7
                z: 10 - ao * 2
                opacity: Math.max(0, Math.min(1, (2.7 - ao) / 0.6))

                Cartridge {
                    id: cart
                    entry: place.app
                    // the slot's: rising when launched; gone once let go
                    opacity: place.ao < 0.5 && self.letGoDone ? 0 : 1
                    number: place.idx + 1
                    lit: place.ao < 0.5
                    scale: place.s
                    transformOrigin: Item.Center
                    x: unit.X(place.cx) - width / 2
                    y: unit.Y(place.cy) - height / 2 - (place.ao < 0.5 ? self.rise : 0)
                }
                MouseArea {
                    x: unit.X(place.cx) - 350 * place.s / 2; y: unit.Y(place.cy) - 445 * place.s / 2
                    width: 350 * place.s; height: 445 * place.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: place.ao < 0.5 ? self.launch() : self.choose(place.idx)
                }
            }
        }

        // the clamp's rods and lower bracket, in front of the slot's cartridge
        Image {
            anchors.fill: parent
            z: 20
            source: self.art("clamp.png")
            smooth: true; mipmap: true
        }

        // ---- the screen (glass 222-1373 x 540-842)
        Item {
            id: lcd
            z: 30
            readonly property color ink: "#2a2c2a"
            component Lcd: Text {
                color: lcd.ink
                font.family: "VT323"
                font.pixelSize: 50
                // a heavier stroke, as the mock-up's (VT323 has one weight)
                style: Text.Outline; styleColor: color
            }
            component Line: Rectangle { x: unit.X(248); width: 1100; height: 3; color: lcd.ink }

            // the index, and where in it
            Canvas {
                x: unit.X(271); y: unit.Y(575); width: 36; height: 28
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.strokeStyle = lcd.ink; c.lineWidth = 3;
                    c.strokeRect(9, 1.5, 25, 18); c.strokeRect(1.5, 8, 25, 18);
                    c.fillStyle = "#c9cac6"; c.fillRect(3, 9.5, 22, 15);
                    c.fillStyle = lcd.ink; c.fillRect(6, 14, 16, 2.5); c.fillRect(6, 19, 11, 2.5);
                }
            }
            Lcd { x: unit.X(333); y: unit.Y(588) - height / 2; text: "APPLICATION INDEX"; font.letterSpacing: 1 }
            Lcd {
                x: unit.X(1322) - width; y: unit.Y(588) - height / 2
                readonly property string n: String(self.results.length).padStart(2, "0")
                text: (self.results.length ? String(self.sel + 1).padStart(2, "0") : "00") + " / " + n
            }
            Line { y: unit.Y(616) }

            // the search
            Canvas {
                x: unit.X(270); y: unit.Y(633); width: 32; height: 32
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.strokeStyle = lcd.ink; c.lineWidth = 3.4; c.lineCap = "round";
                    c.beginPath(); c.arc(13, 13, 9.5, 0, Math.PI * 2); c.stroke();
                    c.beginPath(); c.moveTo(20, 20); c.lineTo(29, 29); c.stroke();
                }
            }
            SystemClock { id: tick; precision: SystemClock.Seconds; enabled: self.shown }
            Lcd {
                x: unit.X(333); y: unit.Y(648) - height / 2
                text: "SEARCH > " + self.query.toLowerCase() + (tick.date.getSeconds() % 2 === 0 || !self.shown ? "_" : " ")
            }
            Line { y: unit.Y(676) }

            // the chosen app: its icon, as the screen shows it, its name, its state
            Rectangle {
                x: unit.X(282); y: unit.Y(694); width: 179; height: 119; radius: 6
                color: "#3b3c3a"
                Image {
                    id: mono
                    anchors.centerIn: parent
                    width: 96; height: 96
                    source: self.current && self.current.icon ? Quickshell.iconPath(self.current.icon, true) : ""
                    sourceSize: Qt.size(128, 128)
                    smooth: true
                    visible: false
                }
                MultiEffect {
                    source: mono
                    anchors.fill: mono
                    saturation: -1
                    brightness: 0.55
                    contrast: 0.5
                    visible: mono.status === Image.Ready
                }
                Lcd {
                    anchors.centerIn: parent
                    visible: !self.current || mono.status !== Image.Ready
                    color: "#d6d7d2"; font.pixelSize: 60
                    text: self.current ? self.current.name.charAt(0).toUpperCase() : "?"
                }
            }
            Rectangle { x: unit.X(488); y: unit.Y(694); width: 3; height: 119; color: lcd.ink }
            Lcd {
                x: unit.X(523); y: unit.Y(724) - height / 2
                width: 800; elide: Text.ElideRight
                text: self.current ? self.current.name.toUpperCase() : "NO CARTRIDGE"
                font.pixelSize: 84; font.letterSpacing: 2
            }
            Item {
                // the state, on a dark slanted chip, and its slashes
                x: unit.X(517); y: unit.Y(770)
                Canvas {
                    width: 440; height: 36
                    onPaint: {
                        const c = getContext("2d"); c.reset(); c.fillStyle = "#4a4b48";
                        c.beginPath(); c.moveTo(0, 2); c.lineTo(430, 2); c.lineTo(414, 34); c.lineTo(0, 34); c.closePath(); c.fill();
                    }
                }
                Lcd {
                    x: 22; y: 18 - height / 2
                    color: "#d9dad5"; font.pixelSize: 46; font.letterSpacing: 2.5
                    text: self.current ? "READY / SELECTED" : (self.query !== "" ? "NOTHING MATCHES" : "NO APPS")
                }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: 446 + index * 26; y: 2; width: 13; height: 32; color: "#4a4b48"
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.5, 0, 16, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                }
            }
        }
    }
}
