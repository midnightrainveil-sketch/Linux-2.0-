import QtQuick
import Quickshell
import qs.components
import qs.services

// The cassette vending machine (art/CassetteVending.png): your music as
// cassettes on its shelves, one for each song in ~/Music (ultra-tapes;
// services/Tapes.qml). Super + V, or REC on the cassette player.
//
//   choosing     the wheel (mouse or touchpad, or the arrows by the wheel),
//                the arrow keys, Page Up / Down (a rack at a time), Home /
//                End, or a click on a cassette; the shelves run up and down
//                past the window, and the lift's carriage rides its screw to
//                the chosen one's height
//   searching    just type: the shelves keep the songs that match
//                (Backspace, or the ← key; Esc clears; Esc again puts it away)
//   dispensing   Enter, SELECT / EJECT, or a click on the chosen cassette:
//                the carriage draws it off its shelf, carries it down and
//                drops it in the tray, step by step on the screen; then the
//                cassette player comes up and it goes in and plays
//
// The song in the player is missing from its shelf. Everything is placed in
// the mock-up's own pixels (body.png starts at its 83, 15;
// tools/make_vending.py) and the whole machine scaled once.
Widget {
    id: self
    widgetId: "vending"

    readonly property real k: 0.66
    preferredWidth: 952 * k
    preferredHeight: 1384 * k

    // ---- what it holds
    property string query: ""
    readonly property var results: Tapes.search(query)
    property int sel: 0
    // the rack: the first song in its window (eased toward first)
    property int first: 0
    property real firstPos: 0
    Behavior on firstPos { id: rackSlide; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property var current: results.length > 0 ? results[Math.max(0, Math.min(sel, results.length - 1))] : null
    readonly property string inPlayer: Tapes.tape ? Tapes.tape.file : ""

    Component.onCompleted: {
        Tapes.read();
        // the song in the player chosen, to begin with
        const i = Tapes.tape ? Tapes.tapes.findIndex(t => t.file === Tapes.tape.file) : -1;
        if (i >= 0) jump(i);
    }
    Connections {
        target: Tapes
        function onTapesChanged() {
            if (self.query === "" && Tapes.tape && self.sel === 0) {
                const i = Tapes.tapes.findIndex(t => t.file === Tapes.tape.file);
                if (i >= 0) self.jump(i);
            }
        }
    }

    function jump(i: int): void {
        rackSlide.enabled = false; lift.enabled = false;
        choose(i);
        rackSlide.enabled = true; lift.enabled = true;
    }
    function choose(i: int): void {
        if (results.length === 0 || phase > 0) return;
        sel = Math.max(0, Math.min(results.length - 1, i));
        if (sel < first) first = sel;
        else if (sel > first + 7) first = sel - 7;
        first = Math.max(0, Math.min(Math.max(0, results.length - 8), first));
        firstPos = first;
    }
    function move(d: int): void { choose(sel + d); }
    onQueryChanged: { rackSlide.enabled = false; sel = 0; first = 0; firstPos = 0; rackSlide.enabled = true; }

    escapeHandler: () => {
        if (phase > 0) return true;
        if (query !== "") { query = ""; return true; }
        return false;
    }
    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Up: case Qt.Key_Left: move(-1); break;
        case Qt.Key_Down: case Qt.Key_Right: case Qt.Key_Tab: move(1); break;
        case Qt.Key_PageUp: move(-8); break;
        case Qt.Key_PageDown: move(8); break;
        case Qt.Key_Home: choose(0); break;
        case Qt.Key_End: choose(results.length - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: press("select"); dispense(); break;
        case Qt.Key_Backspace: press("back"); if (phase === 0) query = query.slice(0, -1); break;
        default:
            if (phase === 0 && e.text !== "" && e.text.charCodeAt(0) > 32 || (e.text === " " && query !== "")) {
                if (!(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && query.length < 24) {
                    query += e.text;
                    break;
                }
            }
            return;
        }
        e.accepted = true;
    }
    property real wheelRest: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? -e.angleDelta.x : e.angleDelta.y;
            self.wheelRest += d;
            const steps = Math.trunc(self.wheelRest / 120);
            if (steps !== 0) { self.wheelRest -= steps * 120; self.move(-steps); self.wheelTurn -= steps; }
        }
    }
    // the wheel by the screen, turned as the choice moves
    property int wheelTurn: 0
    onSelChanged: wheelTurn += 1

    // a button pressed for a moment (by the keyboard)
    property string tapped: ""
    function press(name: string): void { tapped = name; tapTimer.restart(); }
    Timer { id: tapTimer; interval: 160; onTriggered: self.tapped = "" }

    // ---- the shelves, in the mock-up's pixels: each one's foot (where a
    // cassette stands), its number's and its lamp's heights
    readonly property var feet: [165, 276, 386, 501, 616, 726, 831, 936, 1051, 1162]   // shelves -1 .. 8
    readonly property var numberY: [221, 330, 443, 556, 665, 776, 880, 985]
    readonly property var lampY: [242, 353, 466, 580, 690, 800, 905, 1008]
    function footAt(f: real): real {
        const g = Math.max(-1, Math.min(8, f)) + 1, i = Math.min(8, Math.floor(g));
        return feet[i] + (feet[i + 1] - feet[i]) * (g - i);
    }
    // the eight shells (tools/make_vending.py, shells.json): size, title place, ink
    readonly property var shells: [
        { w: 336, h: 99, tx: 46, tw: 188, ty: 29.5, ink: "#2b2a27" },
        { w: 336, h: 89, tx: 46, tw: 192, ty: 25.0, ink: "#2b2a27" },
        { w: 336, h: 91, tx: 82, tw: 186, ty: 23.5, ink: "#e6dfcd" },
        { w: 336, h: 94, tx: 46, tw: 190, ty: 27.5, ink: "#2b2a27" },
        { w: 336, h: 89, tx: 58, tw: 184, ty: 26.5, ink: "#2b2a27" },
        { w: 336, h: 84, tx: 43, tw: 145, ty: 23.5, ink: "#e6dfcd" },
        { w: 337, h: 86, tx: 92, tw: 160, ty: 22.0, ink: "#3a3936" },
        { w: 336, h: 95, tx: 72, tw: 194, ty: 24.5, ink: "#e6dfcd" }
    ]
    function shellOf(t: var): var { return shells[t ? Math.max(0, Math.min(7, t.shell ?? 0)) : 0]; }

    // ---- the lift: where its carriage is (0 at rest, over the tray; less, higher)
    readonly property real holdX: 697
    readonly property real holdY: 968
    // level with the chosen shelf, while choosing
    readonly property real chosenLift: current ? footAt(sel - firstPos) - shellOf(current).h / 2 - holdY : 0
    property real liftY: 0
    Binding on liftY { when: self.phase === 0; value: self.chosenLift; restoreMode: Binding.RestoreNone }
    Behavior on liftY { id: lift; enabled: self.phase === 0; NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

    // ---- dispensing: 1 select, 2 extract, 3 transfer, 4 dispense, 5 done
    property int phase: 0
    property var taking: null              // the song being dispensed
    property int takingIdx: -1
    // the cassette on its way: its middle and its size
    property real cx: 0
    property real cy: 0
    property real cs: 1
    property real trayLit: 0
    function dispense(): void {
        if (!current || phase > 0) return;
        if (current.file === inPlayer) { Widgets.open("cassette"); return; }
        taking = current;
        takingIdx = sel;
        const s = shellOf(current);
        cx = 204 + s.w / 2;
        cy = footAt(sel - firstPos) - s.h / 2;
        cs = 1;
        liftY = chosenLift;
        down.duration = 380 + Math.abs(liftY) * 0.75;
        phase = 1;
        dispenseAnim.restart();
    }
    SequentialAnimation {
        id: dispenseAnim
        // 1: the carriage is at the shelf (it followed the choice); a beat
        PauseAnimation { duration: 260 }
        // 2: drawn off the shelf, into the carriage's jaws
        ScriptAction { script: self.phase = 2 }
        ParallelAnimation {
            NumberAnimation { target: self; property: "cx"; to: self.holdX; duration: 520; easing.type: Easing.InOutCubic }
            NumberAnimation { target: self; property: "cs"; to: 0.68; duration: 520; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: 120 }
        // 3: carried down the screw
        ScriptAction { script: { self.carry = self.cy - self.liftY; self.phase = 3; } }
        NumberAnimation { id: down; target: self; property: "liftY"; to: 0; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 140 }
        // 4: let go: through the jaws, into the tray
        ScriptAction { script: self.phase = 4 }
        ParallelAnimation {
            NumberAnimation { target: self; property: "trayLit"; to: 1; duration: 200 }
            SequentialAnimation {
                NumberAnimation { target: self; property: "cy"; to: 1200; duration: 200; easing.type: Easing.InQuad }
                ParallelAnimation {
                    NumberAnimation { target: self; property: "cx"; to: 561; duration: 380; easing.type: Easing.OutCubic }
                    NumberAnimation { id: toTray; target: self; property: "cy"; to: 1214; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: self; property: "cs"; to: 1.2; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
                }
            }
        }
        // 5: done; then the player takes it
        ScriptAction { script: self.phase = 5 }
        PauseAnimation { duration: 700 }
        ScriptAction {
            script: {
                Tapes.fresh = true;
                Tapes.insert(self.taking, false);
                Widgets.open("cassette");
            }
        }
    }
    // (while carried, the cassette rides with the carriage)
    property real carry: 0
    Binding on cy { when: self.phase === 3; value: self.liftY + self.carry; restoreMode: Binding.RestoreNone }

    // ======================================================================
    // the machine, in the mock-up's pixels
    Item {
        id: unit
        width: 952; height: 1384
        scale: self.k
        transformOrigin: Item.TopLeft
        function ax(x) { return x - 83; }
        function ay(y) { return y - 15; }

        Image {
            anchors.fill: parent
            source: self.art("body.png")
            smooth: true; mipmap: true
        }

        // ---- a cassette: its shell and, where its own title was, the song's
        component Cassette: Item {
            id: cas
            property var t: null
            readonly property var s: self.shellOf(t)
            width: s.w; height: s.h
            Image {
                anchors.fill: parent
                source: cas.t ? self.art("shell-" + Math.max(0, Math.min(7, cas.t.shell ?? 0)) + ".png") : ""
                smooth: true; mipmap: true
            }
            Text {
                x: cas.s.tx; width: cas.s.tw
                y: cas.s.ty - height / 2
                text: cas.t ? cas.t.title : ""
                elide: Text.ElideRight
                color: cas.s.ink
                font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 19; font.letterSpacing: 0.5
            }
        }

        // ---- the shelves: the songs from the rack's top, ten places (one
        // above and one below the window, for the slide)
        Item {
            id: bay
            x: unit.ax(176); y: unit.ay(160); width: 390; height: 902
            clip: true
            Repeater {
                model: 10
                Item {
                    id: place
                    required property int index
                    readonly property int idx: Math.floor(self.firstPos) + index - 1
                    readonly property var t: idx >= 0 && idx < self.results.length ? self.results[idx] : null
                    readonly property real slot: idx - self.firstPos
                    readonly property bool chosen: idx === self.sel
                    readonly property bool away: t !== null && (t.file === self.inPlayer
                        || (self.phase >= 2 && idx === self.takingIdx))
                    readonly property real foot: self.footAt(slot)
                    visible: t !== null
                    Cassette {
                        t: place.t
                        visible: !place.away
                        x: 204 - 176
                        y: place.foot - height - 160
                    }
                    // the song in the player: its place empty, and said so
                    Text {
                        visible: place.away && place.t.file === self.inPlayer && self.phase === 0
                        x: 204 - 176; width: 336
                        y: place.foot - 160 - 52
                        horizontalAlignment: Text.AlignHCenter
                        text: "▸  IN THE PLAYER"
                        color: "#8b847a"
                        font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 17; font.letterSpacing: 4
                    }
                    MouseArea {
                        x: 204 - 176; width: 336
                        y: place.foot - 160 - 96; height: 96
                        enabled: self.phase === 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: place.chosen ? self.dispense() : self.choose(place.idx)
                    }
                }
            }
            // nothing on the shelves
            Column {
                visible: Tapes.readOnce && self.results.length === 0
                x: 204 - 176; width: 336
                y: 276 - 160 - 66
                spacing: 6
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: self.query !== "" ? "NOTHING MATCHES" : "THE SHELVES ARE EMPTY"
                    color: "#9a9389"
                    font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 19; font.letterSpacing: 3
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: self.query !== "" ? "ESC TO CLEAR" : "PUT SONGS IN  " + (Tapes.musicRoot !== "" ? Tapes.musicRoot.replace(/^\/home\/[^/]+/, "~") : "~/Music")
                    color: "#7a746b"
                    font.family: "Barlow"; font.weight: Font.Medium; font.pixelSize: 15; font.letterSpacing: 2
                }
            }
        }

        // ---- the shelves' numbers and lamps
        Repeater {
            model: 8
            Item {
                id: mark
                required property int index
                readonly property int n: self.first + index
                readonly property bool lit: self.results.length > 0 && n === self.sel
                Text {
                    x: unit.ax(144) - width / 2; y: unit.ay(self.numberY[mark.index]) - height / 2
                    text: String(mark.n + 1).padStart(2, "0")
                    color: "#3b3936"
                    opacity: mark.n < self.results.length ? 1 : 0.35
                    font.family: "Barlow"; font.weight: Font.Medium
                    font.pixelSize: mark.n + 1 >= 100 ? 20 : 25
                    font.letterSpacing: 0.5
                }
                // the lamp: a small grey glass, orange when chosen
                Rectangle {
                    x: unit.ax(144) - 8; y: unit.ay(self.lampY[mark.index]) - 8; width: 16; height: 16; radius: 8
                    color: "#8d877d"
                    border.width: 2; border.color: "#bdb5a6"
                    Rectangle {
                        anchors.centerIn: parent; width: 10; height: 10; radius: 5
                        color: "#6e695f"
                    }
                }
                Rectangle {
                    x: unit.ax(144) - 11; y: unit.ay(self.lampY[mark.index]) - 11; width: 22; height: 22; radius: 11
                    opacity: mark.lit ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffe7a8" }
                        GradientStop { position: 0.5; color: "#ffb444" }
                        GradientStop { position: 1; color: "#e07a1c" }
                    }
                    border.width: 2; border.color: "#f3c98a"
                    Rectangle {
                        anchors.centerIn: parent; width: 44; height: 44; radius: 22
                        z: -1
                        color: "#ff9a2e"; opacity: 0.22
                    }
                }
            }
        }

        // ---- the lift: its carriage (in its column), the cassette it carries
        Item {
            id: column
            x: unit.ax(560); y: unit.ay(150); width: 280; height: 990
            clip: true
            z: 5
            Image {
                x: 578 - 560; y: 860 - 150 + self.liftY
                source: self.art("carriage.png")
                smooth: true; mipmap: true
            }
        }
        Image {
            x: unit.ax(575); y: unit.ay(140)
            z: 7
            source: self.art("motor.png")
            smooth: true; mipmap: true
        }
        Cassette {
            id: moving
            t: self.taking
            visible: self.phase >= 2 && self.taking !== null
            z: self.phase >= 4 ? 4 : 8
            x: unit.ax(self.cx) - width / 2; y: unit.ay(self.cy) - height / 2
            scale: self.cs
            transformOrigin: Item.Center
            MouseArea {
                anchors.fill: parent
                enabled: self.phase === 5
                cursorShape: Qt.PointingHandCursor
                onClicked: { Tapes.fresh = true; Tapes.insert(self.taking, false); Widgets.open("cassette"); }
            }
        }
        // the tray's clips, over a cassette in it
        Image {
            x: unit.ax(348); y: unit.ay(1238)
            z: 6
            source: self.art("clips.png")
            smooth: true
            visible: self.phase >= 4
        }
        // the tray's lamp
        Rectangle {
            x: unit.ax(486); y: unit.ay(1125); width: 100; height: 7; radius: 3.5
            z: 6
            opacity: self.trayLit
            color: "#ffcf85"
            Rectangle {
                anchors.centerIn: parent; width: parent.width + 30; height: 26; radius: 13
                z: -1; color: "#ff9a2e"; opacity: 0.25
            }
        }

        // ---- the buttons: the wheel's arrows, SELECT / EJECT, back
        component Button: MouseArea {
            id: btn
            property string name
            property real r: 12
            readonly property bool down: pressed || self.tapped === name
            cursorShape: Qt.PointingHandCursor
            Rectangle {
                anchors.fill: parent; radius: btn.r
                color: "black"
                opacity: btn.down ? 0.16 : 0
            }
        }
        Button { name: "up"; x: unit.ax(890); y: unit.ay(480); width: 64; height: 40; r: 10; onClicked: self.move(-1) }
        Button { name: "down"; x: unit.ax(890); y: unit.ay(660); width: 64; height: 40; r: 10; onClicked: self.move(1) }
        // the wheel itself: a drag up or down turns it
        MouseArea {
            x: unit.ax(895); y: unit.ay(520); width: 58; height: 135
            cursorShape: Qt.SizeVerCursor
            property real y0: 0
            onPressed: m => y0 = m.y
            onPositionChanged: m => {
                if (!pressed) return;
                const steps = Math.trunc((m.y - y0) / 22);
                if (steps !== 0) { y0 += steps * 22; self.move(steps); }
            }
            // its knurls, running as it turns
            Item {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                opacity: 0.32
                Column {
                    y: ((self.wheelTurn * 7) % 14) - 14
                    spacing: 4
                    Repeater {
                        model: 14
                        Rectangle { width: 46; height: 3; color: "#1d1c1a"; opacity: 0.6 }
                    }
                }
            }
        }
        Button { name: "select"; x: unit.ax(868); y: unit.ay(740); width: 108; height: 126; r: 16; onClicked: self.dispense() }
        Button {
            name: "back"; x: unit.ax(873); y: unit.ay(905); width: 98; height: 46; r: 14
            onClicked: { if (self.phase > 0) return; if (self.query !== "") self.query = self.query.slice(0, -1); else self.close(); }
        }

        // ---- the screen (e-ink, 858-990 x 184-432)
        Item {
            id: screen
            x: unit.ax(858); y: unit.ay(184); width: 132; height: 248
            readonly property color ink: "#2c2d2a"
            component Ink: Text {
                color: screen.ink
                font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 15
            }
            // the header: a cassette, and what it is doing
            Canvas {
                x: 10; y: 15; width: 34; height: 24
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.strokeStyle = screen.ink; c.fillStyle = screen.ink; c.lineWidth = 2.4;
                    c.strokeRect(1.5, 1.5, 31, 21);
                    c.beginPath(); c.arc(11, 10, 3.2, 0, Math.PI * 2); c.stroke();
                    c.beginPath(); c.arc(23, 10, 3.2, 0, Math.PI * 2); c.stroke();
                    c.fillRect(5, 17, 24, 3);
                }
            }
            Ink {
                x: 48; y: 27 - height / 2
                width: 80; elide: Text.ElideRight
                font.pixelSize: 15; font.letterSpacing: 0.3
                text: self.phase >= 5 ? "DISPENSED" : self.phase > 0 ? "DISPENSING"
                    : self.query !== "" ? "SEARCH" : "ARCHIVE"
            }
            // what it says: the chosen song, the search, or the work in hand
            Text {
                visible: self.phase > 0
                x: 8; y: 58 - height / 2
                color: screen.ink
                font.family: "Shippori Mincho"; font.pixelSize: 21
                text: self.phase >= 5 ? "取出し完了" : "取出し中" + "…".repeat(1)
            }
            Ink {
                visible: self.phase === 0
                x: 9; y: 58 - height / 2; width: 116
                elide: Text.ElideRight
                font.pixelSize: self.query !== "" ? 17 : 18
                SystemClock { id: tick; precision: SystemClock.Seconds }
                text: self.query !== ""
                    ? "> " + self.query.toLowerCase() + (tick.date.getSeconds() % 2 === 0 ? "_" : " ")
                    : self.current ? self.current.title : (Tapes.reading ? "READING…" : "NO TAPES")
            }
            Rectangle { x: 8; y: 81; width: 116; height: 2.5; color: screen.ink }

            // the steps
            Repeater {
                model: ["SELECT", "EXTRACT", "TRANSFER", "DISPENSE"]
                Item {
                    id: step
                    required property int index
                    required property string modelData
                    readonly property int n: index + 1
                    // the one in hand (when choosing, the first)
                    readonly property bool now: self.phase === 0 ? n === 1 : self.phase === n
                    readonly property bool done: self.phase > n
                    x: 8; y: 99 + index * 25 - 11; width: 118; height: 22
                    Rectangle {
                        anchors.fill: parent; radius: 11
                        color: screen.ink
                        visible: step.now
                    }
                    Rectangle {
                        x: 3; y: 3; width: 16; height: 16; radius: 8
                        color: step.now ? "#d7d7cf" : "transparent"
                        border.width: 1.6; border.color: step.now ? "#d7d7cf" : screen.ink
                        Text {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: 0.5
                            text: step.n
                            color: screen.ink
                            font.family: "Barlow"; font.weight: Font.Bold; font.pixelSize: 11
                        }
                    }
                    Text {
                        x: 25; anchors.verticalCenter: parent.verticalCenter
                        text: step.modelData
                        color: step.now ? "#e2e2da" : screen.ink
                        font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 14; font.letterSpacing: 0.3
                    }
                    // a tick once done; an arrow on the one in hand
                    Canvas {
                        x: parent.width - 18; y: 4; width: 14; height: 14
                        visible: step.done || step.now
                        property bool tick: step.done
                        onTickChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset();
                            if (tick) {
                                c.strokeStyle = screen.ink; c.lineWidth = 2.2; c.lineCap = "round";
                                c.beginPath(); c.moveTo(2, 7.5); c.lineTo(5.5, 11); c.lineTo(12, 2.5); c.stroke();
                            } else {
                                c.fillStyle = "#e2e2da";
                                c.beginPath(); c.moveTo(4, 2); c.lineTo(12, 7); c.lineTo(4, 12); c.closePath(); c.fill();
                            }
                        }
                    }
                }
            }
            Rectangle { x: 8; y: 196; width: 116; height: 2.5; color: screen.ink }

            // its foot: the mark, and which song of how many
            ArchLogo {
                x: 12; y: 207; width: 30; height: 30
                color: screen.ink
            }
            Ink {
                x: 124 - width; y: 223 - height / 2
                font.pixelSize: 21; font.letterSpacing: 0.5
                readonly property int n: self.results.length
                readonly property int w: Math.max(2, String(n).length)
                text: (n ? String(self.sel + 1).padStart(w, "0") : "00") + " / " + String(n).padStart(2, "0")
            }
        }
    }
}
