import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components

// The label typewriter: the herbarium's machine for typing labels, used
// here for one quick line. What you type goes onto a determination slip in
// the platen (the carriage moves along as you type, the keys go down); the
// line under it says what Return will do:
//
//   = 12 * 4.5   (or just 12*4.5)   calculate; Return copies the answer
//   > command                       run it in a terminal
//   example.org/page                open it
//   anything else                   search the web (the "search" setting)
//
// Escape, or a click outside, puts the cover back on.
PanelWindow {
    id: win

    readonly property string name: "typewriter"
    readonly property bool shown: Panels.open === name

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-typewriter"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || slide > 0.001
    mask: Region { item: win.shown ? catcher : null }

    // ---------------------------------------------------------------- what the line means
    readonly property string line: input.text
    readonly property var plan: decide(line)

    // a sum, worked safely: only numbers, operators, brackets and a few
    // named functions get through; anything else is not a sum
    function calculate(src: string): var {
        let s = src.trim().replace(/^=\s*/, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "");
        if (s === "") return null;
        const fns = { sqrt: "Math.sqrt", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan", log: "Math.log10",
                      ln: "Math.log", abs: "Math.abs", round: "Math.round", floor: "Math.floor", ceil: "Math.ceil",
                      pi: "Math.PI", e: "Math.E" };
        const tokens = s.match(/\d+(\.\d+)?|\.\d+|[a-z]+|\*\*|[-+*/%^()]|\s+/gi);
        if (!tokens || tokens.join("") !== s) return null;
        let out = "", ops = 0, nums = 0;
        for (const t of tokens) {
            if (/^\s+$/.test(t)) continue;
            if (/^[a-z]+$/i.test(t)) {
                const f = fns[t.toLowerCase()];
                if (!f) return null;
                out += f;
                nums++;
            } else if (/^[\d.]/.test(t)) { out += t; nums++; }
            else if (t === "^") { out += "**"; ops++; }
            else { out += t; if (t !== "(" && t !== ")") ops++; }
        }
        // a bare number or word ("e", "pi") is not a sum, unless asked for with =
        if (nums === 0 || (ops === 0 && !src.trim().startsWith("=") && !s.includes("("))) return null;
        try {
            const v = Function("\"use strict\"; return (" + out + ");")();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return v;
        } catch (e) {
            return null;
        }
    }
    function figure(v: real): string {
        if (Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0)) return v.toExponential(6).replace(/\.?0+e/, "e");
        let s = String(Number(v.toPrecision(12)));
        const [i, d] = s.split(".");
        return i.replace(/\B(?=(\d{3})+(?!\d))/g, ",") + (d ? "." + d : "");
    }

    function decide(t: string): var {
        const s = t.trim();
        if (s === "") return { kind: "", says: "=  a sum      >  a command      a page's address, or words to look up" };
        if (s.startsWith(">")) {
            const cmd = s.substring(1).trim();
            return { kind: "run", says: cmd === "" ? "Run …" : "Run in a terminal", cmd };
        }
        const v = calculate(s);
        if (v !== null) return { kind: "sum", says: "= " + figure(v), value: String(Number(v.toPrecision(12))) };
        if (s.startsWith("=")) return { kind: "", says: "= …" };
        if (/^(https?:\/\/)\S+$/i.test(s) || /^(www\.)?[\w-]+(\.[\w-]+)*\.[a-z]{2,}(:\d+)?(\/\S*)?$/i.test(s))
            return { kind: "open", says: "Open " + s.replace(/^https?:\/\//i, ""), url: /^https?:\/\//i.test(s) ? s : "https://" + s };
        const engine = Settings.get("search", "https://duckduckgo.com/?q=%s");
        const host = (engine.match(/^https?:\/\/(?:www\.)?([^/]+)/) ?? ["", "the web"])[1];
        return { kind: "search", says: "Look it up (" + host + ")", url: engine.replace("%s", encodeURIComponent(s)) };
    }

    function act(): void {
        const p = plan;
        if (p.kind === "" || finishing.running) return;
        Sounds.play("bell");
        if (p.kind === "sum") {
            Quickshell.execDetached(["wl-copy", p.value]);
            copied.visible = true;
            copied.press();
            finishing.pause = Theme.dur(650);
        } else {
            if (p.kind === "run")
                Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c", p.cmd + "; printf '\\n(Return closes this) '; read _"]);
            else
                Quickshell.execDetached(["xdg-open", p.url]);
            finishing.pause = 0;
        }
        finishing.restart();
    }
    // Return: the carriage flies back, the slip is wound up and out of the
    // platen, and the cover goes on
    SequentialAnimation {
        id: finishing
        property int pause: 0
        ScriptAction { script: carriageReturn.restart() }
        PauseAnimation { duration: Theme.dur(280) + finishing.pause }
        NumberAnimation { target: win; property: "feed"; to: 2.3; duration: Theme.dur(420); easing.type: Easing.InCubic }
        ScriptAction { script: Panels.close() }
    }

    // the slip winding in when the cover comes off (0: inside the machine,
    // 1: in place, more: wound out of the top)
    property real feed: 0
    SequentialAnimation {
        id: feedIn
        PauseAnimation { duration: Theme.dur(160) }
        NumberAnimation { target: win; property: "feed"; from: 0; to: 1; duration: Theme.dur(520); easing.type: Easing.OutCubic }
    }

    onShownChanged: {
        if (shown) {
            input.text = "";
            copied.visible = false;
            carriage.back = 0;
            finishing.stop();
            feed = 0;
            feedIn.restart();
            input.forceActiveFocus();
        }
    }

    // ---------------------------------------------------------------- motion
    property real slide: shown ? 1 : 0
    Behavior on slide {
        NumberAnimation {
            duration: win.shown ? Theme.dur(480) : Theme.dur(240)
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.7
        }
    }

    // ---------------------------------------------------------------- the room
    Item { id: catcher; anchors.fill: parent }
    Rectangle {
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#050b16" : "#1e1d22"
        opacity: 0.22 * win.slide
    }
    MouseArea { anchors.fill: parent; onClicked: Panels.close() }
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (Panels.open === win.name) Panels.close()
    }

    // ---------------------------------------------------------------- the machine
    readonly property color enamel: Theme.night > 0.5 ? "#141e30" : "#2c312b"     // bottle-green enamel
    readonly property color chrome: Theme.night > 0.5 ? "#8e9cb3" : "#b9b6b0"
    readonly property color brass: Theme.night > 0.5 ? "#7d8aa1" : "#a68a5b"

    // the keys' letters, as on the machine
    readonly property var rows: ["1234567890-", "QWERTYUIOP", "ASDFGHJKL;", "ZXCVBNM,./"]
    property string struck: ""
    property int strikes: 0

    // The machine is the photograph in assets/typewriter (tools/import_objects.py)
    // when it is there, else drawn. Measured on the 1586 x 992 photograph: the
    // keys' centres, the space bar, the type guide where the letters strike,
    // the platen's top, the basket of typebars.
    readonly property bool art: machineImg.status === Image.Ready
    readonly property real artScale: 800 / 1586
    readonly property var keyAt: {
        const at = {};
        const rows = [["QWERTYUIOP", 388, 1192, 557], ["ASDFGHJKL", 420, 1153, 641], ["ZXCVBNM", 455, 1017, 722]];
        for (const [keys, x0, x1, y] of rows)
            for (let i = 0; i < keys.length; i++) at[keys[i]] = Qt.point(x0 + (x1 - x0) * i / (keys.length - 1), y);
        return at;
    }

    TextInput {
        id: input
        visible: false
        focus: true
        maximumLength: 200
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { Panels.close(); e.accepted = true; return; }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { win.act(); e.accepted = true; return; }
            if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Home || e.key === Qt.Key_End) { e.accepted = true; return; }
            win.struck = e.key === Qt.Key_Space ? " " : e.text.toUpperCase();
            win.strikes += 1;
        }
    }

    Item {
        id: stage
        width: 840
        height: win.art ? 660 : 600
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - Theme.barHeight - height - 10 + (1 - win.slide) * (height + 60)
        opacity: Math.min(1, win.slide * 3)

        MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

        readonly property real strikeX: width / 2          // where the type hits the paper
        readonly property real platenY: win.art ? 190 : 196
        // the photograph's place: its platen's top at platenY, its type
        // guide under strikeX
        readonly property real mx: strikeX - 782 * win.artScale
        readonly property real my: platenY - 95 * win.artScale
        function onMachine(x, y) { return Qt.point(mx + x * win.artScale, my + y * win.artScale); }

        // ------------------------------------------------------------ the slip, in the carriage
        TextMetrics {
            id: typed
            font.family: Theme.typewriter
            font.pixelSize: 21
            text: win.line
        }
        Item {
            id: carriage
            readonly property real travel: Math.min(typed.advanceWidth, slip.width - 70)
            property real back: 0             // the carriage returned (Return)
            x: stage.strikeX - 34 - travel + back
            Behavior on x {
                enabled: !carriageReturn.running
                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
            }
            // wound in from behind the platen; wound out over the top
            y: (1 - win.feed) * 205
            opacity: win.feed > 1.6 ? Math.max(0, 2.3 - win.feed) / 0.7 : 1
            width: slip.width
            height: stage.platenY + 20

            Paper {
                id: slip
                width: 560
                height: 214
                y: 8
                seed: 4100
                lift: 1.2
            }
            InkText {
                x: 34; y: 22
                text: "Determination slip"
                caps: true
                tracking: 0.14
                font.pixelSize: 11
                color: Theme.soft
            }
            InkText {
                anchors.right: slip.right
                anchors.rightMargin: 24
                y: 22
                text: "Herb. " + Settings.archiveStamp
                font.pixelSize: 11
                color: Theme.faded
            }
            Rule { x: 20; y: 42; width: slip.width - 40; height: implicitHeight; weight: 1; seed: 4101 }

            // the line, and what it will do
            Item {
                x: 34
                y: 62
                width: slip.width - 68
                height: 34
                clip: true
                InkText {
                    id: lineText
                    x: Math.min(0, parent.width - 18 - typed.advanceWidth)
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.line
                    font.pixelSize: 21
                    color: Theme.graphite
                    spread: 0.6
                }
                // where the next letter lands
                Rectangle {
                    x: lineText.x + typed.advanceWidth + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11; height: 3
                    y: parent.height - 7
                    color: Theme.madder
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: win.shown
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 520 }
                        NumberAnimation { to: 0.15; duration: 0 }
                        PauseAnimation { duration: 520 }
                    }
                }
            }
            Rule { x: 30; y: 98; width: slip.width - 60; height: implicitHeight; weight: 0.8; color: Theme.ruleFaint; seed: 4102 }
            InkText {
                x: 34
                y: 108
                width: slip.width - 68
                text: win.plan.says
                font.pixelSize: win.plan.kind === "sum" ? 21 : 14
                color: win.plan.kind === "" ? Theme.faded : (win.plan.kind === "sum" ? Theme.accent : Theme.soft)
                elide: Text.ElideRight
            }
            InkText {
                x: 34
                y: 160
                text: "Det. " + Settings.user + "   " + Qt.formatDate(new Date(), "d.M.yyyy")
                font.pixelSize: 11
                color: Theme.faded
            }
            Stamp {
                id: copied
                visible: false
                kind: "box"
                word: "COPIED"
                ink: Theme.accent
                seed: 4103
                x: slip.width - width - 40
                y: 130
            }
        }

        // ------------------------------------------------------------ the photographed machine
        DropShadow {
            visible: win.art
            anchors.fill: machine
            source: machine
            radius: 26
            samples: 33
            verticalOffset: 12
            color: Qt.rgba(0, 0, 0, 0.42)
        }
        Item {
            id: machine
            visible: win.art
            x: stage.mx
            y: stage.my
            width: 800
            height: 992 * win.artScale
            // every key jolts the frame a little
            transform: Translate { y: hold.running ? 1 : 0 }
            Image {
                id: machineImg
                anchors.fill: parent
                source: Qt.resolvedUrl("../../assets/typewriter/typewriter.png")
                sourceSize: Qt.size(1586, 992)
                smooth: true
                mipmap: true
            }
            Colorize {
                anchors.fill: parent
                source: machineImg
                visible: Theme.night > 0.01
                opacity: Theme.night
                hue: 0.6; saturation: 0.3; lightness: -0.08
            }
        }
        // the brass decal, on the front band between the pinstripes
        Rectangle {
            visible: win.art
            readonly property point at: stage.onMachine(790, 893)
            x: at.x - width / 2
            y: at.y - height / 2
            width: artDecal.implicitWidth + 22
            height: 16
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(win.brass, 1.2) }
                GradientStop { position: 1; color: Qt.darker(win.brass, 1.25) }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.45)
            Text {
                id: artDecal
                anchors.centerIn: parent
                text: "❦  LABEL TYPEWRITER  ❦"
                font.family: Theme.typewriter
                font.pixelSize: 8
                font.letterSpacing: 2
                font.bold: true
                color: Qt.rgba(0.12, 0.09, 0.05, 0.8)
            }
        }
        // a key going down: its own picture, a little lower and smaller, in
        // the shadow of its well
        Item {
            id: pressed
            readonly property var at: win.keyAt[win.struck] ?? null
            readonly property real r: 19
            visible: win.art && hold.running && at !== null
            x: stage.mx + (at ? at.x : 0) * win.artScale - r
            y: stage.my + (at ? at.y : 0) * win.artScale - r
            width: 2 * r
            height: 2 * r
            Rectangle { anchors.fill: parent; anchors.margins: -1; radius: width / 2; color: Qt.rgba(0.04, 0.05, 0.04, 0.9) }
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: machine
                sourceRect: Qt.rect((pressed.at ? pressed.at.x : 0) * win.artScale - pressed.r, (pressed.at ? pressed.at.y : 0) * win.artScale - pressed.r, 2 * pressed.r, 2 * pressed.r)
                y: 4
                scale: 0.88
                // further from the light, down in its well
                Rectangle { anchors.fill: parent; radius: width / 2; color: "black"; opacity: 0.2 }
            }
        }
        // the space bar, likewise
        Item {
            id: spacePressed
            readonly property rect bar: Qt.rect(402, 785, 778, 55)
            visible: win.art && hold.running && win.struck === " "
            x: stage.mx + bar.x * win.artScale
            y: stage.my + bar.y * win.artScale
            width: bar.width * win.artScale
            height: bar.height * win.artScale
            Rectangle { anchors.fill: parent; radius: 6; color: Qt.rgba(0.04, 0.05, 0.04, 0.9) }
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: machine
                sourceRect: Qt.rect(spacePressed.bar.x * win.artScale, spacePressed.bar.y * win.artScale, spacePressed.width, spacePressed.height)
                y: 4
                scale: 0.97
                Rectangle { anchors.fill: parent; radius: 6; color: "black"; opacity: 0.18 }
            }
        }

        // ------------------------------------------------------------ the platen and the bail
        Item {
            id: platen
            visible: !win.art
            x: 30
            y: stage.platenY - 6
            width: stage.width - 60
            height: 42
            // the knobs at its ends
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: index === 0 ? -26 : platen.width - 4
                    y: 4
                    width: 30; height: 34; radius: 8
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#3b3936" }
                        GradientStop { position: 0.4; color: "#77746e" }
                        GradientStop { position: 1; color: "#1c1b1a" }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.6)
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: "#141313" }
                    GradientStop { position: 0.35; color: "#3c3a39" }
                    GradientStop { position: 0.6; color: "#1f1e1d" }
                    GradientStop { position: 1; color: "#0c0c0c" }
                }
            }
            // the paper bail, chrome, with its rollers
            Rectangle {
                y: -8
                width: parent.width
                height: 5
                radius: 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(win.chrome, 1.2) }
                    GradientStop { position: 1; color: Qt.darker(win.chrome, 1.5) }
                }
            }
            Repeater {
                model: [0.3, 0.7]
                Rectangle {
                    required property real modelData
                    x: platen.width * modelData - 9
                    y: -11
                    width: 18; height: 11; radius: 3
                    color: "#2a2928"
                }
            }
        }

        // the carriage return lever
        Canvas {
            visible: !win.art
            x: 6
            y: stage.platenY - 52
            width: 90; height: 60
            readonly property color c: win.chrome
            onCChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.strokeStyle = String(c);
                g.lineCap = "round";
                g.lineWidth = 7;
                g.beginPath(); g.moveTo(48, 50); g.quadraticCurveTo(30, 20, 8, 12); g.stroke();
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.35);
                g.lineWidth = 2;
                g.beginPath(); g.moveTo(46, 47); g.quadraticCurveTo(30, 19, 9, 10); g.stroke();
            }
        }

        // ------------------------------------------------------------ the body
        DropShadow {
            visible: !win.art
            anchors.fill: body
            source: body
            radius: 24
            samples: 33
            verticalOffset: 12
            color: Qt.rgba(0, 0, 0, 0.45)
        }
        Canvas {
            id: body
            visible: !win.art
            x: 0
            y: stage.platenY + 34
            width: stage.width
            height: stage.height - y
            readonly property color e: win.enamel
            onEChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const w = width, h = height;
                // the body: wider at the bottom, its shoulders rounded
                g.beginPath();
                g.moveTo(70, 0); g.lineTo(w - 70, 0);
                g.quadraticCurveTo(w - 40, 0, w - 34, 30);
                g.lineTo(w - 6, h - 30); g.quadraticCurveTo(w - 4, h - 4, w - 30, h - 4);
                g.lineTo(30, h - 4); g.quadraticCurveTo(4, h - 4, 6, h - 30);
                g.lineTo(34, 30); g.quadraticCurveTo(40, 0, 70, 0);
                g.closePath();
                const grad = g.createLinearGradient(0, 0, 0, h);
                grad.addColorStop(0, String(Qt.lighter(e, 1.5)));
                grad.addColorStop(0.15, String(e));
                grad.addColorStop(1, String(Qt.darker(e, 1.3)));
                g.fillStyle = grad;
                g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.6); g.lineWidth = 1.2; g.stroke();
                // lit enamel along the shoulders
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.12); g.lineWidth = 2;
                g.beginPath(); g.moveTo(72, 3); g.lineTo(w - 72, 3); g.stroke();
                // the segment: the typebars lying in their basket
                const cx = w / 2, cy = 8;
                g.fillStyle = Qt.rgba(0, 0, 0, 0.55);
                g.beginPath(); g.ellipse(cx - 190, cy - 52, 380, 150); g.fill();
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.16);
                g.lineWidth = 1.4;
                for (let i = 0; i <= 36; i++) {
                    const a = Math.PI * (0.06 + 0.88 * i / 36);
                    g.beginPath();
                    g.moveTo(cx + Math.cos(a) * 40, cy + Math.sin(a) * 18);
                    g.lineTo(cx + Math.cos(a) * 180, cy + Math.sin(a) * 66);
                    g.stroke();
                }
                // the keyboard's well
                g.fillStyle = Qt.rgba(0, 0, 0, 0.28);
                g.beginPath(); g.roundedRect(54, 96, w - 108, h - 150, 14, 14); g.fill();
            }
        }

        // the typebar: on every key one swings up out of the basket and
        // strikes the paper at the guide
        Rectangle {
            id: typebar
            readonly property string order: "1QAZ2WSX3EDC4RFV5TGB6YHN7UJM8IK,9OL.0P;/- "
            readonly property real fanAngle: {
                const i = Math.max(0, order.indexOf(win.struck));
                return Math.PI * (0.94 - 0.88 * i / (order.length - 1));
            }
            // from its place in the basket's ring to the type guide
            readonly property point from: win.art
                ? stage.onMachine(790 + Math.cos(fanAngle) * 315, 300 + Math.sin(fanAngle) * 170)
                : Qt.point(stage.width / 2 + Math.cos(fanAngle) * 176, body.y + 8 + Math.sin(fanAngle) * 62)
            readonly property point to: win.art ? stage.onMachine(782, 200) : Qt.point(stage.strikeX, stage.platenY + 18)
            property real reach: 0
            visible: reach > 0.01
            x: from.x
            y: from.y - height / 2
            height: 4
            radius: 2
            width: Math.hypot(to.x - from.x, to.y - from.y) * reach
            transformOrigin: Item.Left
            rotation: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(win.chrome, 1.3) }
                GradientStop { position: 1; color: Qt.darker(win.chrome, 1.4) }
            }
            // the slug at its end, with the letter on it
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 9; height: 8; radius: 1.5
                color: Qt.darker(win.chrome, 1.2)
                visible: typebar.reach > 0.6
            }
            SequentialAnimation {
                id: swing
                NumberAnimation { target: typebar; property: "reach"; from: 0.15; to: 1; duration: 45; easing.type: Easing.InQuad }
                NumberAnimation { target: typebar; property: "reach"; to: 0; duration: 95; easing.type: Easing.OutQuad }
            }
            Connections {
                target: win
                function onStrikesChanged() { if (win.struck !== " ") swing.restart(); }
            }
        }

        // the type guide and the ribbon, where the letters strike
        Item {
            visible: !win.art
            x: stage.strikeX - 22
            y: stage.platenY - 2
            width: 44
            height: 40
            Rectangle {
                id: ribbon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
                width: 34; height: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: "#1a1a1a" }
                    GradientStop { position: 0.5; color: "#1a1a1a" }
                    GradientStop { position: 0.51; color: Theme.night > 0.5 ? "#8e5a66" : "#7a2f2a" }
                    GradientStop { position: 1; color: Theme.night > 0.5 ? "#8e5a66" : "#7a2f2a" }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                width: 18; height: 30
                radius: 2
                color: "transparent"
                border.width: 3
                border.color: win.chrome
            }
            // a strike: the ribbon jumps up to meet the type
            SequentialAnimation {
                id: strike
                NumberAnimation { target: ribbon; property: "y"; to: 4; duration: 35 }
                NumberAnimation { target: ribbon; property: "y"; to: 16; duration: 70 }
            }
            Connections {
                target: win
                function onStrikesChanged() { strike.restart(); }
            }
        }

        // the brass decal
        Rectangle {
            visible: !win.art
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.platenY + 128
            width: decal.implicitWidth + 30
            height: 22
            radius: 3
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(win.brass, 1.2) }
                GradientStop { position: 1; color: Qt.darker(win.brass, 1.2) }
            }
            Text {
                id: decal
                anchors.centerIn: parent
                text: "❦  LABEL TYPEWRITER  ❦"
                font.family: Theme.typewriter
                font.pixelSize: 11
                font.letterSpacing: 2.5
                color: Qt.rgba(0.12, 0.09, 0.05, 0.8)
            }
        }

        // ------------------------------------------------------------ the keys
        Column {
            id: keyboard
            visible: !win.art
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.platenY + 168
            spacing: 6
            Repeater {
                model: win.rows
                Row {
                    id: keyRow
                    required property string modelData
                    required property int index
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: index * 9 - 12
                    spacing: 9
                    Repeater {
                        model: keyRow.modelData.split("")
                        Item {
                            id: key
                            required property string modelData
                            readonly property bool down: win.struck === modelData && hold.running
                            width: 40; height: 40
                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 3
                                radius: 20
                                color: Qt.rgba(0, 0, 0, 0.45)
                            }
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                y: key.down ? 3 : 0
                                scale: key.down ? 0.93 : 1
                                Behavior on y { NumberAnimation { duration: 40 } }
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(win.chrome, 1.25) }
                                    GradientStop { position: 1; color: Qt.darker(win.chrome, 1.6) }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32; height: 32; radius: 16
                                    color: Theme.night > 0.5 ? "#e6e1d6" : "#efe9dc"
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.35)
                                    Text {
                                        anchors.centerIn: parent
                                        text: key.modelData
                                        font.family: Theme.typewriter
                                        font.pixelSize: 15
                                        font.bold: true
                                        color: "#1e1d22"
                                    }
                                    // the glass over the letter
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.35) }
                                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // the space bar
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 330; height: 22
                readonly property bool down: win.struck === " " && hold.running
                Rectangle { anchors.fill: parent; anchors.topMargin: 3; radius: 6; color: Qt.rgba(0, 0, 0, 0.45) }
                Rectangle {
                    width: parent.width; height: parent.height; radius: 6
                    y: parent.down ? 3 : 0
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(win.chrome, 1.2) }
                        GradientStop { position: 1; color: Qt.darker(win.chrome, 1.6) }
                    }
                }
            }
        }
        // a key stays down a moment
        Timer {
            id: hold
            interval: 110
        }
        Connections {
            target: win
            function onStrikesChanged() { hold.restart(); }
        }
    }

    // the carriage flies back on Return
    SequentialAnimation {
        id: carriageReturn
        NumberAnimation { target: carriage; property: "back"; to: carriage.travel + 36; duration: Theme.dur(160); easing.type: Easing.OutCubic }
        NumberAnimation { target: carriage; property: "back"; to: carriage.travel; duration: Theme.dur(120); easing.type: Easing.OutBack }
    }
}
