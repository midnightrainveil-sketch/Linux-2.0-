import QtQuick
import Quickshell
import qs.components
import qs.services

// The control deck (art/ControlDeck.png): the machine's settings on one
// gadget. Comes up over the taskbar's readouts (click Wi-Fi, volume or the
// battery there; Super + S), stays over the windows, nothing behind blurred.
//
//   screen        the battery, Wi-Fi, Bluetooth, power mode, refresh rate and
//                 colour profile, as they are now
//   WI-FI, BT     switches: click or drag
//   POWER         Quiet / Balanced / Performance
//   REFRESH RATE  60 Hz / 120 Hz / Auto (120 plugged in, 60 on battery)
//   LOCK AFTER    2, 5, 10, 30 min or never: click a mark or drag the tab
//   VOLUME, BRIGHTNESS   faders: drag, click the track, or the wheel
//
// Keys: W and B the switches, 1 2 3 the power mode, R the refresh rate, L the
// lock time, Up / Down the volume, Left / Right the brightness, M mute, Esc.
//
// Its pictures (deck.png and the parts that move) are made from the mock-up
// by tools/make_controldeck.py; everything here is placed in the mock-up's
// own pixels (deck.png starts at its 50, 28) and the whole deck scaled once.
Widget {
    id: self
    widgetId: "controls"

    readonly property real k: 0.52                    // the mock-up at this size
    preferredWidth: 1562 * k
    preferredHeight: 920 * k
    // deck.png's body ends at the mock-up's 1592 x 916; past it, its shadow
    airRight: (1612 - 1592) * k
    airBottom: (948 - 916) * k

    // ---- the look
    readonly property color lcdInk: "#2a2c2a"
    readonly property color lcdGhost: Qt.rgba(0.16, 0.17, 0.16, 0.07)
    readonly property color plateInk: "#3b3b3d"
    readonly property color indigo: "#565aa6"
    readonly property string lcdFace: "VT323"
    readonly property string plateFace: "Barlow"

    // ---- what the deck shows and sets
    readonly property var modes: [
        { id: "power-saver", word: "QUIET" },
        { id: "balanced", word: "BALANCED" },
        { id: "performance", word: "PERFORMANCE" }
    ]
    readonly property var rates: [
        { id: "60", word: "60 Hz" }, { id: "120", word: "120 Hz" }, { id: "auto", word: "AUTO" }
    ]
    readonly property var locks: [
        { id: "2", word: "2m", x: 850 }, { id: "5", word: "5m", x: 994 }, { id: "10", word: "10m", x: 1144 },
        { id: "30", word: "30m", x: 1293 }, { id: "never", word: "NEVER", x: 1438 }
    ]
    function lockIndex(): int {
        const i = locks.findIndex(l => l.id === Machine.lockAfter);
        if (i >= 0) return i;
        // a time set elsewhere: the nearest mark
        const m = parseInt(Machine.lockAfter);
        if (isNaN(m)) return 4;
        let best = 0;
        locks.forEach((l, j) => { if (l.id !== "never" && Math.abs(parseInt(l.id) - m) < Math.abs(parseInt(locks[best].id) - m)) best = j; });
        return best;
    }
    function nextMode(d: int): void {
        const i = modes.findIndex(m => m.id === Power.profile);
        Power.setProfile(modes[(i + d + modes.length) % modes.length].id);
    }

    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_W: Net.setWifi(!Net.wifiOn); break;
        case Qt.Key_B: if (Net.bluetoothAvailable) Net.setBluetooth(!Net.bluetoothOn); break;
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: Power.setProfile(modes[e.key - Qt.Key_1].id); break;
        case Qt.Key_R: {
            const i = rates.findIndex(r => r.id === Machine.refresh);
            Machine.setRefresh(rates[(i + 1) % rates.length].id); break;
        }
        case Qt.Key_L: Machine.setLockAfter(locks[(lockIndex() + 1) % locks.length].id); break;
        case Qt.Key_Up: Audio.setVolume(Math.min(1, Audio.volume + 0.05)); break;
        case Qt.Key_Down: Audio.setVolume(Math.max(0, Audio.volume - 0.05)); break;
        case Qt.Key_Right: Brightness.set(Math.min(100, Brightness.percent + 5)); break;
        case Qt.Key_Left: Brightness.set(Math.max(1, Brightness.percent - 5)); break;
        case Qt.Key_M: Audio.toggleMute(); break;
        default: return;
        }
        e.accepted = true;
    }

    onOpened: { Machine.readColour(); Brightness.refresh(); }

    // ======================================================================
    // the deck, in the mock-up's pixels
    Item {
        id: deck
        width: 1562; height: 920
        scale: self.k
        transformOrigin: Item.TopLeft
        function X(x) { return x - 50; }               // a point of the mock-up
        function Y(y) { return y - 28; }

        Image {
            anchors.fill: parent
            source: self.art("deck.png")
            smooth: true; mipmap: true
        }

        // ---- the screen (glass 212-959 x 176-497) ---------------------------
        Item {
            id: lcd
            x: deck.X(212); y: deck.Y(176); width: 747; height: 321
            component Lcd: Text {
                color: self.lcdInk
                font.family: self.lcdFace
                font.pixelSize: 40
                style: Text.Raised; styleColor: self.lcdGhost      // the faint shadow of LCD ink
            }
            // header
            Row {
                x: 30; y: 8; spacing: 22
                Repeater {
                    model: 3
                    Rectangle {
                        width: 13; height: 30; y: 6; color: self.lcdInk
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.55, 0, 16, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                }
            }
            Lcd { x: 148; y: 0; text: "SYSTEM CONTROL"; font.pixelSize: 50; font.letterSpacing: 2 }
            Rectangle { x: 22; y: 54; width: 693; height: 2.5; color: self.lcdInk }

            // left: the battery
            Lcd { x: 40; y: 70; text: Power.present ? "BATTERY" : "POWER" }
            Row {
                x: 40; y: 108; width: 210
                Item { width: (parent.width - figure.implicitWidth - percent.implicitWidth) / 2; height: 1 }
                Lcd { id: figure; text: Power.present ? Power.percent : "AC"; font.pixelSize: 112 }
                Lcd { id: percent; y: 44; text: Power.present ? "%" : ""; font.pixelSize: 54 }
            }
            Item {
                // the cells: one bar, filled to the charge
                x: 40; y: 236; width: 206; height: 56
                visible: Power.present
                Rectangle { width: 192; height: 56; color: "transparent"; border.width: 4; border.color: self.lcdInk }
                Rectangle { x: 192; y: 16; width: 12; height: 24; color: self.lcdInk }
                Row {
                    x: 10; y: 10; spacing: 6
                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index
                            width: 24; height: 36
                            color: self.lcdInk
                            opacity: index < Math.ceil(Power.percent / 100 * 6) ? 1 : 0.08
                        }
                    }
                }
            }
            Rectangle { x: 296; y: 76; width: 2.5; height: 230; color: self.lcdInk }

            // right: the state of things
            Column {
                x: 336; y: 62; spacing: 0
                Lcd {
                    text: (Power.present ? Power.stateWord.toUpperCase() : "ON MAINS")
                        + (Power.remaining !== "" ? "  " + Power.remaining.replace(" h ", ":").replace(" min", "").replace(/:(\d)$/, ":0$1") : "")
                    font.pixelSize: 40
                }
                Item { width: 1; height: 8 }
                Repeater {
                    model: [
                        ["WI-FI", !Net.wifiOn ? "OFF" : Net.wired ? "WIRED" : Net.ssid !== "" ? Net.ssid.toUpperCase() : "ON"],
                        ["BLUETOOTH", !Net.bluetoothAvailable ? "NONE" : !Net.bluetoothOn ? "OFF"
                            : Net.bluetoothConnected > 0 ? Net.bluetoothConnected + " ON" : "ON"],
                        ["POWER", (self.modes.find(m => m.id === Power.profile) ?? { word: "-" }).word.slice(0, 8)],
                        ["DISPLAY", Machine.refresh === "auto" ? "AUTO" : Machine.refresh + "HZ"],
                        ["COLOUR", Machine.colourName.toUpperCase()]
                    ]
                    Item {
                        required property var modelData
                        width: 380; height: 38
                        Lcd { text: modelData[0]; font.pixelSize: 36 }
                        Lcd {
                            x: 196; width: 184; elide: Text.ElideRight
                            text: modelData[1]; font.pixelSize: 36
                        }
                    }
                }
            }
        }

        // ---- WI-FI and BT: switches (slots 1100-1243 and 1372-1511, y 203-257)
        component Switch: Item {
            id: sw
            required property real sx                  // the slot's left edge
            property bool on: false
            property bool usable: true
            signal flipped(bool to)
            x: deck.X(sx - 30); y: deck.Y(200)
            width: 176; height: 100
            opacity: usable ? 1 : 0.5
            // the lamp beside it
            Rectangle {
                x: 6; y: 14; width: 8; height: 32; radius: 2
                color: sw.on ? "#4d55c4" : "#9a9aa0"
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                    anchors.centerIn: parent; width: 18; height: 42; radius: 6
                    color: "#6d76ff"; opacity: sw.on ? 0.22 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
            // the blue showing beside the knob when it is over to ON (and as
            // it slides there)
            Rectangle {
                x: 36; y: 8; height: 42; radius: 7
                readonly property real onness: Math.max(0, Math.min(1, (knob.offX - knob.x) / (knob.offX - knob.onX)))
                width: Math.max(0, knob.x - 32) * onness
                visible: width > 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#7c87cf" }
                    GradientStop { position: 0.5; color: "#6370b8" }
                    GradientStop { position: 1.0; color: "#4c5797" }
                }
            }
            Image {
                id: knob
                source: self.art("knob.png")
                y: 6
                readonly property real onX: 61
                readonly property real offX: 102
                x: area.dragging ? area.dragX : (sw.on ? onX : offX)
                Behavior on x { enabled: !area.dragging; NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                smooth: true; mipmap: true
            }
            // ON / OFF under it, the one in force darker
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.horizontalCenterOffset: 14
                y: 66; spacing: 12
                Text { text: "ON"; color: self.plateInk; opacity: sw.on ? 1 : 0.35; font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 26 }
                Text { text: "/"; color: self.plateInk; opacity: 0.35; font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 26 }
                Text { text: "OFF"; color: self.plateInk; opacity: sw.on ? 0.35 : 1; font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 26 }
            }
            // click to flip; or slide the knob over and let go
            MouseArea {
                id: area
                x: 30; width: 146; height: 60
                enabled: sw.usable
                cursorShape: Qt.PointingHandCursor
                property bool dragging: false
                property real dragX: 0
                property real pressX: 0
                property real startKnob: 0
                onPressed: e => { pressX = e.x; startKnob = knob.x; dragging = false; }
                onPositionChanged: e => {
                    if (!pressed) return;
                    if (!dragging && Math.abs(e.x - pressX) > 4) dragging = true;
                    if (dragging) dragX = Math.max(knob.onX, Math.min(knob.offX, startKnob + e.x - pressX));
                }
                onReleased: {
                    if (dragging) {
                        const to = dragX < (knob.onX + knob.offX) / 2;
                        dragging = false;
                        if (to !== sw.on) sw.flipped(to);
                    } else {
                        sw.flipped(!sw.on);
                    }
                }
                onCanceled: dragging = false
            }
        }
        Switch { sx: 1100; on: Net.wifiOn; onFlipped: to => Net.setWifi(to) }
        Switch { sx: 1372; on: Net.bluetoothOn; usable: Net.bluetoothAvailable; onFlipped: to => Net.setBluetooth(to) }

        // ---- a round button, as the mock-up's (up, or lit), pressed in a little
        component Key: Item {
            id: key
            property bool lit: false
            property string up: "key-up.png"
            property string litArt: "key-lit.png"
            property string label: ""
            property bool labelOn: false                // the label on the button (refresh) or under it (power)
            signal hit()
            Image {
                anchors.fill: parent
                source: self.art(key.lit ? key.litArt : key.up)
                smooth: true; mipmap: true
                scale: keyArea.pressed ? 0.965 : 1
                y: keyArea.pressed ? 2 : 0
                Behavior on scale { NumberAnimation { duration: 80 } }
                Text {
                    visible: key.labelOn
                    anchors.centerIn: parent; anchors.verticalCenterOffset: -2
                    text: key.label
                    color: key.lit ? "#f3f3fb" : "#2f3033"
                    style: key.lit ? Text.Raised : Text.Normal; styleColor: "#3a3f7a"
                    font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 30
                }
            }
            MouseArea { id: keyArea; anchors.fill: parent; anchors.margins: 4; cursorShape: Qt.PointingHandCursor; onClicked: key.hit() }
        }

        // ---- POWER: the three modes (buttons 1065-1547 x 379-441)
        Text {
            x: deck.X(1305) - width / 2; y: deck.Y(347) - height / 2
            text: "POWER"; color: self.plateInk
            font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 30; font.letterSpacing: 1.5
        }
        Repeater {
            model: self.modes
            Item {
                id: mode
                required property var modelData
                required property int index
                readonly property real cx: [1134, 1308, 1480][index]
                readonly property bool lit: Power.profile === modelData.id
                Key {
                    x: deck.X(mode.cx - 73); y: deck.Y(376)
                    width: 146; height: 69
                    lit: mode.lit
                    onHit: Power.setProfile(mode.modelData.id)
                }
                Text {
                    x: deck.X(mode.cx) - width / 2; y: deck.Y(464) - height / 2
                    text: mode.modelData.word
                    color: mode.lit ? "#2c2d6e" : self.plateInk
                    font.family: self.plateFace; font.weight: Font.Bold
                    font.pixelSize: mode.index === 2 ? 23 : 26
                }
                Rectangle {
                    x: deck.X(mode.cx - 30); y: deck.Y(485)
                    width: 60; height: 4; radius: 2; color: self.indigo
                    opacity: mode.lit ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }
        }

        // ---- REFRESH RATE (buttons 161-663 x 607-674)
        Text {
            x: deck.X(168); y: deck.Y(582) - height / 2
            text: "REFRESH RATE"; color: self.plateInk
            font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 30; font.letterSpacing: 1.5
        }
        Repeater {
            model: self.rates
            Key {
                required property var modelData
                required property int index
                x: deck.X([158, 333, 510][index]); y: deck.Y(604)
                width: 156; height: 73
                up: "rate-up.png"; litArt: "rate-lit.png"
                label: modelData.word; labelOn: true
                lit: Machine.refresh === modelData.id
                onHit: Machine.setRefresh(modelData.id)
            }
        }

        // ---- LOCK AFTER (track 846-1458, y 625; marks at 2m ... never)
        Text {
            x: deck.X(840); y: deck.Y(582) - height / 2
            text: "LOCK AFTER"; color: self.plateInk
            font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 30; font.letterSpacing: 1.5
        }
        Item {
            id: lockBar
            x: deck.X(836); y: deck.Y(596); width: 632; height: 80
            readonly property int at: self.lockIndex()
            function nearest(px) {               // px within this item
                let best = 0;
                self.locks.forEach((l, j) => { if (Math.abs(l.x - 836 - px) < Math.abs(self.locks[best].x - 836 - px)) best = j; });
                return best;
            }
            Image {
                id: tab
                source: self.art("tab.png")
                y: 8
                x: lockArea.pressed ? Math.max(0, Math.min(lockBar.width - width, lockArea.mouseX - width / 2))
                                    : self.locks[lockBar.at].x - 836 - width / 2
                Behavior on x { enabled: !lockArea.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                smooth: true; mipmap: true
            }
            MouseArea {
                id: lockArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onReleased: Machine.setLockAfter(self.locks[lockBar.nearest(mouseX)].id)
            }
        }

        // ---- VOLUME and BRIGHTNESS: faders (tracks 222-682 and 943-1393)
        component Fader: Item {
            id: fader
            required property real track0                   // the track's left end, in the mock-up
            property real value: 0                           // 0..1
            property bool muted: false
            property real readoutX: 0
            signal moved(real v)
            readonly property real lo: track0 + 38           // where the thumb's middle can go
            readonly property real hi: track0 + 422
            x: deck.X(track0); y: deck.Y(752); width: 470; height: 100
            Image {
                source: self.art("fader.png")
                y: 9
                x: (fader.lo + (fader.hi - fader.lo) * Math.max(0, Math.min(1, fader.value))) - fader.track0 - width / 2
                Behavior on x { enabled: !faderArea.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                smooth: true; mipmap: true
            }
            MouseArea {
                id: faderArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function at(mx) { return Math.max(0, Math.min(1, (mx + fader.track0 - fader.lo) / (fader.hi - fader.lo))); }
                onPressed: e => fader.moved(at(e.x))
                onPositionChanged: e => { if (pressed) fader.moved(at(e.x)); }
                onWheel: e => fader.moved(Math.max(0, Math.min(1, fader.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
            // its read-out: the figure, glowing white
            Text {
                x: fader.readoutX - fader.track0 - width / 2 + 0; y: 50 - height / 2
                text: fader.muted ? "--" : Math.round(Math.max(0, Math.min(1, fader.value)) * 100)
                color: "#f4f6f8"
                style: Text.Outline; styleColor: Qt.rgba(0.8, 0.9, 1, 0.18)
                font.family: self.lcdFace; font.pixelSize: 58
            }
        }
        Fader {
            track0: 222; readoutX: 746
            value: Audio.volume; muted: Audio.muted
            onMoved: v => { if (Audio.muted) Audio.toggleMute(); Audio.setVolume(v); }
        }
        Fader {
            track0: 943; readoutX: 1478
            value: Brightness.percent / 100
            onMoved: v => Brightness.set(Math.max(1, Math.round(v * 100)))
        }
        Text {
            x: deck.X(1203) - width / 2; y: deck.Y(736) - height / 2
            text: "BRIGHTNESS"; color: self.plateInk
            font.family: self.plateFace; font.weight: Font.Bold; font.pixelSize: 28; font.letterSpacing: 0.5
        }
    }
}
