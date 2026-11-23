import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.services

// The cassette player (art/CassettePlayerWidget.png). It plays the cassette
// the vending machine (widgets/vending, Super + V) last dispensed: one song
// from your ~/Music (services/Tapes.qml). Super + A.
//
//   the keys      PLAY (it stays down while the tape runs; again, to pause),
//                 REW / FF (held: the tape winds, faster the longer; a tap
//                 skips a little), STOP/EJ (stops; again, the cassette comes
//                 out), REC (opens the vending machine, for another)
//                 The four below the window do the same.
//   the knob      the volume: the wheel over it, or a drag across it
//   keyboard      Space play / pause, Left / Right skip ten seconds (held:
//                 wind), Up / Down the volume, S stop, E eject, Home back to
//                 the start, V the vending machine
//
// The reels turn while the tape runs (racing while it winds), the tape
// moves from one spool to the other as the song goes, the meter shows its
// levels (services/Spectrum.qml) and the lamp is lit while it plays.
// Everything is placed in the mock-up's pixels (body.png starts at its
// 128, 14; tools/make_tapedeck.py) and the whole player scaled once.
Widget {
    id: self
    widgetId: "cassette"

    readonly property real k: 0.82
    preferredWidth: 1334 * k
    preferredHeight: 944 * k

    // what the window holds: the cassette in the player, kept while it
    // slides out
    property var held: Tapes.fresh ? null : Tapes.tape
    // the cassette's slide: 0 seated, 1 out above the window
    property real out: Tapes.fresh ? 1 : 0
    readonly property bool busy: inAnim.running || outAnim.running

    onShownChanged: Tapes.watchers += shown ? 1 : -1
    Component.onDestruction: if (shown) Tapes.watchers -= 1
    Component.onCompleted: Tapes.read()
    onOpened: {
        if (Tapes.fresh) { Tapes.fresh = false; goIn(true); }
    }
    // another cassette put in while it is up (or this one gone)
    Connections {
        target: Tapes
        function onTapeChanged() {
            if (self.busy) return;
            if (Tapes.tape === self.held) return;
            if (Tapes.fresh) { Tapes.fresh = false; if (self.held) { self.swap = true; outAnim.restart(); } else self.goIn(true); return; }
            self.held = Tapes.tape;
        }
    }

    property bool startAfter: false
    property bool swap: false
    function goIn(start: bool): void {
        held = Tapes.tape;
        if (!held) return;
        startAfter = start;
        out = 1;
        inAnim.restart();
    }
    function eject(): void {
        if (!held || busy) return;
        press("stop");
        Tapes.stop();
        swap = false;
        outAnim.restart();
    }
    SequentialAnimation {
        id: inAnim
        PauseAnimation { duration: 120 }
        NumberAnimation { target: self; property: "out"; to: -0.02; duration: 420; easing.type: Easing.OutCubic }
        // seated: a small knock
        NumberAnimation { target: self; property: "out"; to: 0; duration: 90; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 220 }
        ScriptAction { script: if (self.startAfter) { self.press("play"); Tapes.play(); } }
    }
    SequentialAnimation {
        id: outAnim
        // the catch lets go: it jumps a little, then slides up and out
        NumberAnimation { target: self; property: "out"; to: 0.06; duration: 90; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 140 }
        NumberAnimation { target: self; property: "out"; to: 1; duration: 320; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                if (self.swap) { self.swap = false; self.goIn(true); return; }
                Tapes.eject();
                self.held = null;
            }
        }
    }

    // ---- the keys' actions
    function playKey(): void {
        if (busy) return;
        if (!held) { Widgets.open("vending"); return; }
        Tapes.toggle();
    }
    function stopKey(): void {
        if (busy || !held) return;
        if (Tapes.playing || Tapes.winding !== 0) Tapes.stop();
        else eject();
    }
    function windKey(dir: int, down: bool): void {
        if (!held || busy) return;
        if (down) Tapes.wind(dir); else Tapes.unwind();
    }
    // a key pressed for a moment (a key the keyboard pressed)
    property string tapped: ""
    function press(name: string): void { tapped = name; tapTimer.restart(); }
    Timer { id: tapTimer; interval: 160; onTriggered: self.tapped = "" }

    property bool leftHeld: false
    property bool rightHeld: false
    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Space: case Qt.Key_K: case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_P:
            press("play"); playKey(); break;
        case Qt.Key_Left:
            if (e.isAutoRepeat) { if (!leftHeld) { leftHeld = true; windKey(-1, true); } }
            else { press("rew"); Tapes.seekBy(-10); }
            break;
        case Qt.Key_Right:
            if (e.isAutoRepeat) { if (!rightHeld) { rightHeld = true; windKey(1, true); } }
            else { press("ff"); Tapes.seekBy(10); }
            break;
        case Qt.Key_Up: Tapes.setVolume(Tapes.volume + 5); break;
        case Qt.Key_Down: Tapes.setVolume(Tapes.volume - 5); break;
        case Qt.Key_S: press("stop"); if (held) Tapes.stop(); break;
        case Qt.Key_E: eject(); break;
        case Qt.Key_Home: Tapes.seekTo(0); break;
        case Qt.Key_V: case Qt.Key_R: press("rec"); Widgets.open("vending"); break;
        default: return;
        }
        e.accepted = true;
    }
    Keys.onReleased: e => {
        if (e.isAutoRepeat) return;
        if (e.key === Qt.Key_Left && leftHeld) { leftHeld = false; windKey(-1, false); }
        if (e.key === Qt.Key_Right && rightHeld) { rightHeld = false; windKey(1, false); }
    }

    // ---- the reels: their angle, run on by the frame at the tape's speed
    // (the fuller spool turns slower), easing up and down
    property real spin: 0
    property real speed: 0                      // degrees a second, now
    readonly property real target: !held || busy ? 0
        : Tapes.winding !== 0 ? Tapes.winding * 1400
        : Tapes.playing ? 150 : 0
    FrameAnimation {
        running: self.shown && (self.speed !== 0 || self.target !== 0)
        onTriggered: {
            const dt = Math.min(0.05, frameTime);
            const a = Math.abs(self.target) > Math.abs(self.speed) ? 6 : 4;
            self.speed += (self.target - self.speed) * Math.min(1, dt * a);
            if (Math.abs(self.speed - self.target) < 0.5) self.speed = self.target;
            self.spin = (self.spin + self.speed * dt) % 360000;
        }
    }

    // ======================================================================
    // the player, in the mock-up's pixels
    Item {
        id: unit
        width: 1334; height: 944
        scale: self.k
        transformOrigin: Item.TopLeft
        function ax(x) { return x - 128; }
        function ay(y) { return y - 14; }

        Image {
            anchors.fill: parent
            source: self.art("body.png")
            smooth: true; mipmap: true
        }

        // ---- the window: the cassette, seen through its glass
        Item {
            id: well
            x: unit.ax(330); y: unit.ay(410); width: 744; height: 306
            clip: true

            // nothing in it: a sign swung down from the top of the window
            FlipSign {
                x: (744 - width) / 2; y: 64
                width: 360; height: 84
                shown: !self.held && !self.busy
                text: "NO TAPE"
                lampLevel: 0
            }
            MouseArea {
                anchors.fill: parent
                enabled: !self.held
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Widgets.open("vending")
            }

            Item {
                id: tape
                visible: self.held !== null
                x: 349 - 330; y: 425 - 410 - self.out * 340
                width: 712; height: 281
                readonly property var t: self.held
                readonly property int shell: t ? Math.max(0, Math.min(7, t.shell ?? 0)) : 0

                Image {
                    anchors.fill: parent
                    source: self.art("cassette-" + tape.shell + ".png")
                    smooth: true; mipmap: true
                }
                // the tape on its spools, through its window: wound from the
                // left one onto the right as the song goes
                Item {
                    x: 279; y: 110; width: 165; height: 86
                    clip: true
                    readonly property real p: Tapes.tape === tape.t ? Tapes.progress : 0
                    Repeater {
                        model: 2
                        Item {
                            required property int index
                            readonly property real full: index === 0 ? 1 - parent.p : parent.p
                            readonly property real r: Math.sqrt(46 * 46 + (156 * 156 - 46 * 46) * full)
                            readonly property real cx: (index === 0 ? 211 : 510) - 279
                            x: cx - r; y: 150 - 110 - r; width: r * 2; height: r * 2
                            Rectangle {
                                anchors.fill: parent; radius: width / 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "#6b4528" }
                                    GradientStop { position: 0.5; color: "#563620" }
                                    GradientStop { position: 1; color: "#3c2616" }
                                }
                            }
                            // the wound tape's rings
                            Repeater {
                                model: 5
                                Rectangle {
                                    required property int index
                                    readonly property real rr: parent.width / 2 - 6 - index * (parent.width / 2 - 46) / 5
                                    visible: rr > 48
                                    x: parent.width / 2 - rr; y: parent.height / 2 - rr
                                    width: rr * 2; height: rr * 2; radius: rr
                                    color: "transparent"
                                    border.width: 1.5; border.color: index % 2 ? "#2a1a0e" : "#7a5434"
                                    opacity: 0.5
                                }
                            }
                        }
                    }
                    // the window's inner shadow
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#66000000" }
                            GradientStop { position: 0.25; color: "#00000000" }
                            GradientStop { position: 0.8; color: "#00000000" }
                            GradientStop { position: 1; color: "#44000000" }
                        }
                    }
                }
                // the reels' hubs, turning (the take-up one, fuller, slower)
                Repeater {
                    model: 2
                    Image {
                        required property int index
                        source: self.art("reel.png")
                        x: (index === 0 ? 211 : 510) - 45; y: 150 - 45
                        width: 90; height: 90
                        smooth: true; mipmap: true
                        rotation: self.spin * (index === 0 ? 1.15 - 0.4 * Tapes.progress : 0.75 + 0.4 * Tapes.progress) + index * 23
                    }
                }
                // its label: the song, and who, and how far
                Text {
                    x: 185; y: 66 - height + 4
                    width: 390
                    text: tape.t ? tape.t.title : ""
                    elide: Text.ElideRight
                    color: "#2b2a27"
                    font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 27
                }
                Text {
                    x: 185; y: 71
                    width: 390
                    elide: Text.ElideRight
                    readonly property string who: tape.t ? (tape.t.artist || tape.t.album || "") : ""
                    text: (who !== "" ? who.toUpperCase() + "   " : "")
                        + Tapes.time(Tapes.tape === tape.t ? Tapes.position : 0) + " / " + Tapes.time(Tapes.length)
                    color: "#5d5850"
                    font.family: "Barlow"; font.weight: Font.Medium; font.pixelSize: 15; font.letterSpacing: 1.5
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: self.playKey()
                }
            }
        }
        // the glass over it
        Image {
            x: unit.ax(330); y: unit.ay(410)
            source: self.art("glare.png")
            smooth: true
        }

        // ---- the keys: down while pressed; PLAY stays down while the tape runs
        component Key: Image {
            id: key
            property string name
            property var box                             // x0, y0, x1, y1
            property bool latched: false
            property bool hold: false                    // pressed and held (REW / FF)
            signal hit()
            signal holding(bool down)
            readonly property bool down: area.pressed || latched || self.tapped === name
            source: self.art("key-" + name + ".png")
            x: unit.ax(box[0]); y: unit.ay(box[1]) + (down ? 7 : 0)
            smooth: true; mipmap: true
            Behavior on y { NumberAnimation { duration: 60 } }
            Rectangle {
                anchors.fill: parent; radius: 9
                color: "black"
                opacity: key.down ? 0.16 : 0
            }
            MouseArea {
                id: area
                anchors.fill: parent
                anchors.topMargin: key.down ? -7 : 0
                cursorShape: Qt.PointingHandCursor
                onPressed: if (key.hold) key.holding(true)
                onReleased: if (key.hold) key.holding(false)
                onCanceled: if (key.hold) key.holding(false)
                onClicked: if (!key.hold) key.hit()
            }
        }
        Key { name: "rec"; box: [361, 184]; onHit: Widgets.open("vending") }
        Key { name: "play"; box: [471, 184]; latched: Tapes.playing && self.held !== null; onHit: self.playKey() }
        Key { name: "rew"; box: [610, 184]; hold: true; latched: Tapes.winding < 0; onHolding: d => self.windKey(-1, d) }
        Key { name: "ff"; box: [740, 184]; hold: true; latched: Tapes.winding > 0; onHolding: d => self.windKey(1, d) }
        Key { name: "stop"; box: [866, 184]; onHit: self.stopKey() }
        Key { name: "back"; box: [377, 759]; hold: true; latched: Tapes.winding < 0; onHolding: d => self.windKey(-1, d) }
        Key { name: "halt"; box: [542, 759]; onHit: self.stopKey() }
        Key { name: "go"; box: [704, 759]; latched: Tapes.playing && self.held !== null; onHit: self.playKey() }
        Key { name: "fwd"; box: [865, 759]; hold: true; latched: Tapes.winding > 0; onHolding: d => self.windKey(1, d) }

        // ---- the volume knob: its mark on its top, turned with the volume
        Item {
            id: knob
            x: unit.ax(1148); y: unit.ay(178); width: 148; height: 100
            readonly property real cx: 1222 - 1148
            readonly property real cy: 198 - 178
            readonly property real angle: (-150 + 300 * Math.min(130, Tapes.volume) / 130) * Math.PI / 180
            Rectangle {
                width: 17; height: 11; radius: 2.5
                x: knob.cx + 46 * Math.sin(knob.angle) - width / 2
                y: knob.cy - 10.5 * Math.cos(knob.angle) - height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e2643c" }
                    GradientStop { position: 1; color: "#b23e22" }
                }
                border.width: 1; border.color: "#7a2a16"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                property real x0: 0
                property int v0: 0
                onPressed: m => { x0 = m.x; v0 = Tapes.volume; }
                onPositionChanged: m => { if (pressed) Tapes.setVolume(v0 + Math.round((m.x - x0) / 2)); }
                onWheel: w => Tapes.setVolume(Tapes.volume + (w.angleDelta.y > 0 ? 5 : -5))
            }
        }

        // ---- the level meter: seven bars, lit to the music
        Item {
            id: meter
            anchors.fill: parent
            readonly property bool live: Tapes.playing
            opacity: live ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 300 } }
            layer.enabled: visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#ff8a1f"
                shadowBlur: 0.6
                shadowOpacity: 0.85
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                blurMax: 24
            }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    readonly property var xs: [1145, 1168, 1191, 1214, 1237, 1260, 1282]
                    // seven from the six bands, rising toward the right as the mock-up's
                    readonly property real lv: {
                        const L = Spectrum.levels, f = index * 5 / 6, i = Math.floor(f), t = f - i;
                        const v = (L[i] ?? 0) * (1 - t) + (L[Math.min(5, i + 1)] ?? 0) * t;
                        return Math.max(0.1, Math.min(1, v * (0.8 + index * 0.06)));
                    }
                    x: unit.ax(xs[index]); width: 14
                    height: 4 + 48 * lv
                    y: unit.ay(506) - height
                    radius: 1.5
                    Behavior on height { NumberAnimation { duration: 90 } }
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffd27a" }
                        GradientStop { position: 1; color: "#ff9a2e" }
                    }
                }
            }
        }

        // ---- the lamp: lit while it plays, glowing low with a cassette in
        Rectangle {
            id: lamp
            readonly property real level: Tapes.playing ? 1 : (self.held ? 0.35 : 0)
            x: unit.ax(1142.5) - 15; y: unit.ay(611) - 15; width: 30; height: 30; radius: 15
            opacity: level
            Behavior on opacity { NumberAnimation { duration: 250 } }
            gradient: Gradient {
                GradientStop { position: 0; color: "#ffe2a0" }
                GradientStop { position: 0.55; color: "#ffab3d" }
                GradientStop { position: 1; color: "#d9701a" }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#ff9a2e"; shadowBlur: 1; shadowOpacity: 0.9
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 32
            }
        }
    }
}
