import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services
import qs.components

// The lock screen, and the way back in.
//
//   at rest     the room at night; the Suisei clock on the night stand keeps
//               the time and the date. Lock with: qs ipc call lock lock
//               (Super + Escape, the idle timer, the lid)
//   woken       by any key or click (the key counts): the room blurs and the
//               Personal Access Pass drops down (art/Login1.png): who you
//               are, today, a dot for each key of your password, what it is
//               doing. Left alone 25 s with nothing typed, it goes again.
//   unlocked    the pass shoots back up, the blur clears, the room fades into
//               the desk (the city outside the window where the desk has it),
//               and the lock lets go; the taskbar comes up from below.
//
// The pass's buttons: ‖ sleep · POWER shut down (press twice) · USER clear
// the key · SESSION put the pass away · ◀◀ one key back · the roller and ▶▶
// enter. Keys: type, Enter, Backspace, Esc (clear; again, away).
//
// The room is ~/.local/share/ultra/retro-futurism/lock.jpg (its clock's
// window emptied); the pass is assets/pass.png (tools/make_pass.py), what
// is on it drawn here in the mock-up's own pixels (pass.png starts at 38, 26).
Scope {
    id: room

    property string buffer: ""
    property string verdict: ""        // "", "ok", "wrong"
    property bool busy: false
    property bool awake: false         // the pass is out
    property bool leaving: false       // let in: on the way to the desk
    property bool powerAsked: false    // POWER pressed once

    // 0..1 each, eased (the Behaviors below); 'animate' off to set them at once
    property bool animate: true
    readonly property real wantPass: awake && !leaving ? 1 : 0
    property real passLevel: wantPass
    Behavior on passLevel {
        enabled: room.animate
        NumberAnimation {
            duration: room.wantPass > 0 ? 460 : 340
            easing.type: room.wantPass > 0 ? Easing.OutBack : Easing.InBack
            easing.overshoot: 1.1
        }
    }
    property real blurLevel: awake && !leaving ? 1 : 0
    Behavior on blurLevel { enabled: room.animate; NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    property real homeLevel: leaving ? 1 : 0
    Behavior on homeLevel { enabled: room.animate; NumberAnimation { duration: 560; easing.type: Easing.InOutQuad } }

    function reset(): void {
        animate = false;
        awake = false; leaving = false; powerAsked = false;
        buffer = ""; verdict = ""; busy = false;
        Qt.callLater(() => room.animate = true);
    }
    function lock(): void {
        if (sessionLock.locked) return;
        reset();
        sessionLock.locked = true;
    }
    function wake(): void { if (!leaving) awake = true; }
    function rest(): void { if (!busy && !leaving) { awake = false; buffer = ""; verdict = ""; powerAsked = false; } }
    function submit(): void {
        if (busy || leaving || buffer.length === 0) return;
        busy = true;
        verdict = "";
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(room.buffer);
        }
        onCompleted: result => {
            room.busy = false;
            if (result === PamResult.Success) {
                room.verdict = "ok";
                letIn.start();
            } else {
                room.verdict = "wrong";
                room.buffer = "";
            }
        }
        onError: {
            room.busy = false;
            room.verdict = "wrong";
            room.buffer = "";
        }
    }
    // a check that never answers must not leave the pass dead
    Timer {
        interval: 10000
        running: room.busy
        onTriggered: { room.busy = false; room.buffer = ""; room.verdict = "wrong"; }
    }
    // "denied" shows a moment, then the pass is ready again
    Timer { interval: 2200; running: room.verdict === "wrong"; onTriggered: room.verdict = "" }
    Timer { interval: 3000; running: room.powerAsked; onTriggered: room.powerAsked = false }
    // left alone, nothing typed: the pass goes away again
    Timer {
        interval: 25000
        running: room.awake && room.buffer === "" && !room.busy && !room.leaving
        onTriggered: room.rest()
    }
    // let in: "boarding" a moment, then away to the desk, then the lock lets go
    SequentialAnimation {
        id: letIn
        PauseAnimation { duration: 300 }
        ScriptAction { script: room.leaving = true }
        PauseAnimation { duration: 640 }
        ScriptAction { script: sessionLock.locked = false }
        PauseAnimation { duration: 400 }                 // (the lock's surface gone first)
        ScriptAction { script: room.reset() }
    }

    // the clock: ticks every second, only while locked
    SystemClock { id: tick; precision: SystemClock.Seconds }

    WlSessionLock {
        id: sessionLock
        locked: false
        // tell the system the session is locked (logind's LockedHint): the
        // machine's commands that must not act under the lock read it
        // (ultra-refresh, ultra-health wake); and the desk (the taskbar)
        onLockedChanged: {
            Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1",
                "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
                "SetLockedHint", "b", locked ? "true" : "false"]);
            Scene.locked = locked;
            if (!locked) Scene.unlocked();
        }

        WlSessionLockSurface {
            id: surface
            color: "#1a120e"

            // ---- the room (the picture and its clock), blurred when woken
            Item {
                id: roomPicture
                anchors.fill: parent
                visible: false                     // shown through the blur below
                Image {
                    id: picture
                    anchors.fill: parent
                    source: Settings.art + "/lock.jpg"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                }
                readonly property real iw: picture.implicitWidth > 0 ? picture.implicitWidth : 1671
                readonly property real ih: picture.implicitHeight > 0 ? picture.implicitHeight : 941
                readonly property real k: Math.max(width / iw, height / ih)          // picture px -> screen
                readonly property real ox: (width - iw * k) / 2
                readonly property real oy: (height - ih * k) / 2
                function px(x) { return ox + x * k; }
                function py(y) { return oy + y * k; }

                readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
                SevenSegment {
                    // the clock's window: 100,634 to 254,711, turned a little
                    x: roomPicture.px(100); y: roomPicture.py(634)
                    width: 154 * roomPicture.k; height: 77 * roomPicture.k
                    rotation: -1.3
                    visible: picture.status === Image.Ready
                    text: Qt.formatTime(tick.date, "hh:mm")
                    colon: tick.date.getSeconds() % 2 === 0
                }
                DotMatrix {
                    // the date strip: 114,723 to 218,740
                    x: roomPicture.px(114); y: roomPicture.py(723)
                    width: 104 * roomPicture.k; height: 17 * roomPicture.k
                    rotation: -1.0
                    unit: roomPicture.k
                    pitch: 1.45
                    visible: picture.status === Image.Ready
                    text: roomPicture.days[tick.date.getDay()] + " " + tick.date.getDate() + " " + roomPicture.months[tick.date.getMonth()]
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: roomPicture
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: room.blurLevel
                saturation: -0.12 * room.blurLevel
            }
            Rectangle { anchors.fill: parent; color: "#120c08"; opacity: 0.28 * room.blurLevel }

            // ---- the desk, as it will be: faded in on the way out
            Item {
                id: home
                anchors.fill: parent
                opacity: room.homeLevel
                visible: opacity > 0
                scale: 1.012                         // as the desk draws it (room to sway)
                readonly property real iw: 1585
                readonly property real ih: 992
                readonly property real k: Math.max(width / iw, height / ih)
                readonly property real ox: (width - iw * k) / 2
                readonly property real oy: (height - ih * k) / 2
                Item {
                    // the glass: 592,0 to 1400,403; the city where the desk has it
                    x: home.ox + 592 * home.k; y: home.oy
                    width: 808 * home.k; height: 403 * home.k
                    clip: true
                    readonly property real loopW: 1580 * 0.862 * home.k
                    Row {
                        x: -Scene.viewShift * parent.loopW
                        y: (300 - 376 * 0.862) * home.k
                        Repeater {
                            model: 2
                            Image {
                                width: 1580 * 0.862 * home.k; height: 603 * 0.862 * home.k
                                source: Settings.art + "/window-view.jpg"
                                smooth: true
                            }
                        }
                    }
                    Rectangle { anchors.fill: parent; color: "#465578"; opacity: 0.10 }
                }
                Image {
                    anchors.fill: parent
                    source: Settings.art + "/wallpaper-front.png"
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }

            // any click wakes it, and keeps the keyboard on the password
            MouseArea {
                anchors.fill: parent
                onPressed: { room.wake(); field.forceActiveFocus(); }
            }

            // ---- the pass: drops from above when woken, goes back up
            Item {
                id: pass
                readonly property real pk: Math.min(0.62, surface.height * 0.78 / 1201)
                width: 1162 * pk; height: 1201 * pk
                x: (surface.width - width) / 2
                y: -height - 40 + room.passLevel * ((surface.height - height) / 2 + height + 40)
                visible: room.passLevel > 0.001

                PassDevice {
                    id: ticket
                    scale: pass.pk
                    transformOrigin: Item.TopLeft
                    lamp: room.verdict === "wrong"            // the red lamp: the key was wrong
                    onPause: Quickshell.execDetached(["systemctl", "suspend"])
                    onPower: {                                // twice to shut down
                        if (room.powerAsked) Quickshell.execDetached(["systemctl", "poweroff"]);
                        else room.powerAsked = true;
                    }
                    onUser: { room.buffer = ""; room.verdict = ""; }
                    onSession: room.rest()
                    onBack: room.buffer = room.buffer.slice(0, -1)
                    onEnter: room.submit()
                    onRolled: field.forceActiveFocus()

                    // clicks on the pass keep the keyboard on the password
                    MouseArea { anchors.fill: parent; onPressed: field.forceActiveFocus() }


                    component Glow: Text {
                        color: ticket.ink
                        font.family: "Barlow"
                        font.weight: Font.Medium
                    }
                    component Rule: Rectangle { height: 3; color: ticket.ink; opacity: 0.92 }

                    // header: the mark, カセットOS
                    Canvas {
                        x: ticket.X(193); y: ticket.Y(188); width: 154; height: 48
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.fillStyle = ticket.ink;
                            const bar = (y, x0, x1, h) => { c.beginPath(); c.moveTo(x0 + 14, y); c.lineTo(x1 + 14, y); c.lineTo(x1, y + h); c.lineTo(x0, y + h); c.closePath(); c.fill(); };
                            bar(0, 52, 152, 12);           // the mark: a cassette's E, leaning
                            bar(18, 26, 128, 12);
                            bar(36, 0, 140, 12);
                            c.beginPath(); c.moveTo(70, 0); c.lineTo(84, 0); c.lineTo(56, 48); c.lineTo(42, 48); c.closePath(); c.fill();
                        }
                    }
                    Rectangle { x: ticket.X(375); y: ticket.Y(194); width: 3; height: 40; color: ticket.ink }
                    Glow { x: ticket.X(410); y: ticket.Y(192); text: "カセットOS"; font.pixelSize: 34; font.letterSpacing: 6 }

                    Glow { x: ticket.X(184); y: ticket.Y(262); text: "PERSONAL ACCESS PASS"; font.pixelSize: 48; font.weight: Font.DemiBold; font.letterSpacing: 2.9 }
                    Glow { x: ticket.X(186); y: ticket.Y(328); text: "ELECTRONIC BOARDING TICKET"; font.pixelSize: 25; font.letterSpacing: 6.4 }
                    Rule { x: ticket.X(187); y: ticket.Y(377); width: 526 }
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            x: ticket.X(733 + index * 21); y: ticket.Y(366); width: 9; height: 15; color: ticket.ink
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, 9, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        }
                    }

                    // passenger
                    Glow { x: ticket.X(186); y: ticket.Y(424); text: "PASSENGER"; font.pixelSize: 25; font.letterSpacing: 6 }
                    Canvas {
                        x: ticket.X(196); y: ticket.Y(474); width: 52; height: 54
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.fillStyle = ticket.ink;
                            c.beginPath(); c.arc(26, 15, 14, 0, Math.PI * 2); c.fill();
                            c.beginPath(); c.moveTo(0, 54); c.lineTo(0, 46); c.bezierCurveTo(0, 33, 12, 30, 26, 30);
                            c.bezierCurveTo(40, 30, 52, 33, 52, 46); c.lineTo(52, 54); c.closePath(); c.fill();
                        }
                    }
                    Glow {
                        x: ticket.X(274); y: ticket.Y(464); width: 500; elide: Text.ElideRight
                        text: Settings.user; font.pixelSize: 52; font.letterSpacing: 1.4
                    }
                    Rule { x: ticket.X(187); y: ticket.Y(554); width: 579 }

                    // from the lock screen to the desk
                    Glow { x: ticket.X(190); y: ticket.Y(584); text: "FROM"; font.pixelSize: 25; font.letterSpacing: 6 }
                    Glow { x: ticket.X(538); y: ticket.Y(584); text: "TO"; font.pixelSize: 25; font.letterSpacing: 6 }
                    Glow { x: ticket.X(192); y: ticket.Y(616); text: "LOCK\nSCREEN"; font.pixelSize: 42; font.weight: Font.DemiBold; font.letterSpacing: 0.7; lineHeight: 0.98 }
                    Glow { x: ticket.X(538); y: ticket.Y(616); text: "DESKTOP\nSESSION"; font.pixelSize: 42; font.weight: Font.DemiBold; font.letterSpacing: 0.7; lineHeight: 0.98 }
                    Canvas {
                        x: ticket.X(413); y: ticket.Y(634); width: 66; height: 30
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.strokeStyle = ticket.ink; c.lineWidth = 3.2; c.lineCap = "round";
                            c.beginPath(); c.moveTo(2, 15); c.lineTo(62, 15); c.moveTo(48, 3); c.lineTo(62, 15); c.lineTo(48, 27); c.stroke();
                        }
                    }
                    Rule { x: ticket.X(187); y: ticket.Y(734); width: 579 }

                    // today
                    Canvas {
                        x: ticket.X(195); y: ticket.Y(765); width: 42; height: 42
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.strokeStyle = ticket.ink; c.fillStyle = ticket.ink; c.lineWidth = 3;
                            c.strokeRect(2, 6, 38, 34); c.fillRect(2, 6, 38, 9);
                            c.fillRect(9, 0, 4, 10); c.fillRect(29, 0, 4, 10);
                            for (const [a, b] of [[9, 21], [19, 21], [29, 21], [9, 30], [19, 30]]) c.fillRect(a, b, 5, 5);
                        }
                    }
                    readonly property var monthsUp: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
                    Glow {
                        x: ticket.X(270); y: ticket.Y(760)
                        text: tick.date.getDate() + " " + ticket.monthsUp[tick.date.getMonth()] + " " + tick.date.getFullYear()
                        font.pixelSize: 40; font.letterSpacing: 0.4
                        font.features: { "tnum": 1 }
                    }
                    Rectangle { x: ticket.X(532); y: ticket.Y(765); width: 3; height: 41; color: ticket.ink }
                    Canvas {
                        x: ticket.X(577); y: ticket.Y(764); width: 44; height: 44
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.strokeStyle = ticket.ink; c.lineWidth = 3.2; c.lineCap = "round";
                            c.beginPath(); c.arc(22, 22, 19, 0, Math.PI * 2); c.stroke();
                            c.beginPath(); c.moveTo(22, 10); c.lineTo(22, 23); c.lineTo(31, 28); c.stroke();
                        }
                    }
                    Glow {
                        x: ticket.X(651); y: ticket.Y(760)
                        text: Qt.formatTime(tick.date, "hh:mm")
                        font.pixelSize: 40; font.letterSpacing: 0.4
                        font.features: { "tnum": 1 }
                    }
                    Rule { x: ticket.X(187); y: ticket.Y(841); width: 593 }

                    // the access key: a dot for each key, the cursor after them
                    Glow { x: ticket.X(192); y: ticket.Y(873); text: "ACCESS KEY"; font.pixelSize: 25; font.letterSpacing: 6 }
                    Item {
                        id: keyLine
                        x: ticket.X(247); y: ticket.Y(950)
                        readonly property int shown: Math.min(room.buffer.length, 10)
                        Repeater {
                            model: keyLine.shown
                            Rectangle {
                                required property int index
                                x: index * 52.2 - 13; y: -13
                                width: 26; height: 26; radius: 13
                                color: ticket.ink
                                opacity: room.busy ? pulse.level : 1
                                scale: 1
                                Component.onCompleted: popIn.start()
                                NumberAnimation on scale { id: popIn; from: 0.4; to: 1; duration: 120; easing.type: Easing.OutBack; running: false }
                            }
                        }
                        Rectangle {
                            // the cursor
                            x: keyLine.shown === 0 ? -14 : (keyLine.shown - 1) * 52.2 + 36
                            y: -34; width: 4; height: 64
                            color: ticket.ink
                            visible: !room.busy && room.verdict !== "ok"
                            opacity: tick.date.getSeconds() % 2 === 0 ? 1 : 0.15
                        }
                        // a wrong key: the line shakes
                        SequentialAnimation on x {
                            running: room.verdict === "wrong"
                            NumberAnimation { to: ticket.X(247) - 14; duration: 50 }
                            NumberAnimation { to: ticket.X(247) + 14; duration: 70 }
                            NumberAnimation { to: ticket.X(247) - 9; duration: 70 }
                            NumberAnimation { to: ticket.X(247); duration: 60 }
                        }
                    }
                    Rule { x: ticket.X(191); y: ticket.Y(999); width: 590 }

                    // what it is doing
                    Rectangle {
                        x: ticket.X(198); y: ticket.Y(1065); width: 30; height: 30; radius: 15
                        color: room.verdict === "wrong" ? "transparent" : ticket.ink
                        border.width: 3; border.color: ticket.ink
                        opacity: room.busy ? pulse.level : 1
                    }
                    Glow {
                        x: ticket.X(261); y: ticket.Y(1060); width: 400
                        font.pixelSize: 33; font.letterSpacing: 3
                        text: room.verdict === "ok" ? "BOARDING"
                            : room.busy ? "CHECKING"
                            : room.verdict === "wrong" ? "ACCESS DENIED"
                            : room.powerAsked ? "AGAIN: SHUT DOWN"
                            : room.buffer === "" ? "ENTER ACCESS KEY" : "READY TO BOARD"
                    }
                    Rectangle { x: ticket.X(678); y: ticket.Y(1046); width: 3; height: 57; color: ticket.ink }
                    Glow { x: ticket.X(733); y: ticket.Y(1042); text: "TKT No."; font.pixelSize: 25; font.letterSpacing: 3 }
                    Glow {
                        x: ticket.X(733); y: ticket.Y(1070)
                        // a ticket number of your own: from your name
                        text: {
                            let h = 7;
                            for (const ch of Settings.user) h = (h * 31 + ch.charCodeAt(0)) % 1000000;
                            return "KST-" + String(h).padStart(6, "0");
                        }
                        font.pixelSize: 26; font.letterSpacing: 3
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            x: ticket.X(1022 + index * 30); y: ticket.Y(1053); width: 14; height: 40; color: ticket.ink
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.55, 0, 22, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                        }
                    }
                QtObject {
                    id: pulse
                    property real level: 1
                    property var anim: SequentialAnimation {
                        running: room.busy
                        loops: Animation.Infinite
                        NumberAnimation { target: pulse; property: "level"; to: 0.3; duration: 360 }
                        NumberAnimation { target: pulse; property: "level"; to: 1; duration: 360 }
                        onRunningChanged: if (!running) pulse.level = 1
                    }
                }
                }
            }

            // ---- the password itself: typed unseen
            TextInput {
                id: field
                width: 1; height: 1
                opacity: 0
                focus: true
                echoMode: TextInput.Password
                cursorDelegate: Item {}
                // read-only, not disabled, while it checks: a disabled
                // field drops the keyboard and never takes it back
                readOnly: room.busy || room.verdict === "ok" || room.leaving
                onTextChanged: { room.buffer = text; if (text !== "") room.wake(); }
                onAccepted: room.awake ? room.submit() : room.wake()
                Keys.onPressed: e => { room.wake(); e.accepted = false; }
                Keys.onEscapePressed: { if (room.buffer !== "") room.buffer = ""; else room.rest(); }
                Component.onCompleted: forceActiveFocus()
                onActiveFocusChanged: if (!activeFocus) refocus.restart()
                Timer {
                    id: refocus
                    interval: 60
                    onTriggered: if (sessionLock.locked && !field.activeFocus) field.forceActiveFocus()
                }
                Connections {
                    target: sessionLock
                    function onLockedChanged() { if (sessionLock.locked) refocus.restart(); }
                }
                Connections {
                    target: room
                    function onVerdictChanged() { refocus.restart(); }
                    function onBufferChanged() { if (field.text !== room.buffer) field.text = room.buffer; }
                }
            }
        }
    }
}
