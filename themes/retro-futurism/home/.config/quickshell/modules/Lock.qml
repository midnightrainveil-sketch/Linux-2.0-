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
// The pass's buttons: ◀◀ / ▶▶ turn the device to its power face and back
// (components/PowerFace.qml: log in, suspend, log out, restart, shut down,
// chosen with the roller, the arrows or a click, done with Enter or the
// roller); ‖ and POWER (and the laptop's power button) turn it there too,
// with suspend or shut down chosen, never doing it at once. On the pass:
// USER clears the key, SESSION puts the pass away, the roller enters. Keys:
// type, Enter, Backspace, Esc (clear; again, away).
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
    // the device's two faces: "pass" (the key) and "power" (◀◀ / ▶▶ turn
    // it; any power button turns it to power, with that choice made: nothing
    // is done until it is confirmed)
    property string page: "pass"
    property int powerSel: 1
    property bool powerGoing: false
    readonly property var powerOptions: [
        { word: "LOG IN",    doing: "",              icon: "lock" },
        { word: "SUSPEND",   doing: "SUSPENDING",    icon: "moon" },
        { word: "LOG OUT",   doing: "LOGGING OUT",   icon: "exit" },
        { word: "RESTART",   doing: "RESTARTING",    icon: "again" },
        { word: "SHUT DOWN", doing: "SHUTTING DOWN", icon: "power" }
    ]

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
        awake = false; leaving = false;
        page = "pass"; powerSel = 1; powerGoing = false;
        buffer = ""; verdict = ""; busy = false;
        Qt.callLater(() => room.animate = true);
    }
    function lock(): void {
        if (sessionLock.locked) return;
        reset();
        sessionLock.locked = true;
    }
    function wake(): void { if (!leaving) awake = true; }
    function rest(): void { if (!busy && !leaving && !powerGoing) { awake = false; buffer = ""; verdict = ""; page = "pass"; } }

    // ---- the power face
    function flip(): void { if (powerGoing) return; wake(); page = page === "pass" ? "power" : "pass"; }
    function showPower(i: int): void {
        if (leaving || powerGoing) return;
        wake();
        page = "power";
        choosePower(i);
    }
    function choosePower(i: int): void {
        if (powerGoing) return;
        const n = Math.max(0, Math.min(powerOptions.length - 1, i));
        if (n !== powerSel) ticket.roll(n - powerSel);
        powerSel = n;
    }
    function confirmPower(): void {
        if (powerGoing) return;
        if (powerSel === 0) { page = "pass"; return; }        // LOG IN: back to the key
        powerGoing = true;
        powerGo.start();
    }
    // a moment to read what it is doing, then do it
    Timer {
        id: powerGo
        interval: 420
        onTriggered: {
            switch (room.powerSel) {
            case 1: Quickshell.execDetached(["systemctl", "suspend"]); break;
            case 2: Quickshell.execDetached(["ultra-session", "logout"]); break;
            case 3: Quickshell.execDetached(["systemctl", "reboot"]); break;
            case 4: Quickshell.execDetached(["systemctl", "poweroff"]); break;
            }
            // (back from a suspend: the pass, ready)
            if (room.powerSel === 1) resumed.start();
        }
    }
    Timer { id: resumed; interval: 1500; onTriggered: { room.powerGoing = false; room.page = "pass"; room.rest(); } }
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
    // the seconds, only while locked (a timer that stops: nothing ticks otherwise)
    QtObject {
        id: tick
        property date date: new Date()
        property Timer timer: Timer {
            interval: 1000 - (new Date()).getMilliseconds() % 1000 + 5
            repeat: true; triggeredOnStart: true
            running: sessionLock.locked
            onTriggered: { tick.date = new Date(); interval = 1000 - tick.date.getMilliseconds() + 5; }
        }
    }

    // the desk knows whether it is locked (the taskbar waits below while it is)
    Binding { target: Scene; property: "locked"; value: sessionLock.locked }

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
            if (!locked) Scene.unlocked();
        }

        WlSessionLockSurface {
            id: surface
            color: "#1a120e"

            // ---- the room (the picture and its clock), blurred when woken
            Item {
                id: roomPicture
                anchors.fill: parent
                // plain at rest; through the blur (below) only while woken
                visible: room.blurLevel <= 0.001
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
                visible: room.blurLevel > 0.001            // (no effect pass at rest)
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
                scale: 1.075                         // as the desk draws it (room to sway)
                // dimmed as the desk is while windows are open (Backdrop.qml)
                Rectangle {
                    z: 10
                    anchors.fill: parent
                    color: "#0d0907"
                    opacity: Hypr.windows.length > 0 ? 0.5 : 0
                }
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
                    // the red lamp: the key was wrong, or restart / shut down chosen
                    lamp: room.verdict === "wrong" || (room.page === "power" && room.powerSel >= 3)
                    forwardIsEnter: false
                    // power buttons only turn it to its power face, chosen
                    onPause: room.showPower(1)                          // ‖ suspend
                    onPower: room.showPower(4)                          // shut down
                    onUser: room.page === "power" ? room.choosePower(2) : (room.buffer = "", room.verdict = "")
                    onSession: room.page === "power" ? room.choosePower(0) : room.rest()
                    onBack: room.flip()                                  // ◀◀ ▶▶: the other face
                    onForward: room.flip()
                    onEnter: room.page === "power" ? room.confirmPower() : room.submit()
                    onRolled: steps => {
                        if (room.page === "power") {
                            // (the roller has turned already: just the choice)
                            room.powerSel = Math.max(0, Math.min(room.powerOptions.length - 1, room.powerSel + steps));
                        }
                        field.forceActiveFocus();
                    }

                    // clicks on the pass keep the keyboard on the password
                    MouseArea { anchors.fill: parent; onPressed: field.forceActiveFocus() }


                    // the faces: the pass, or (◀◀ / ▶▶, or any power button)
                    // the power face; they cross over as the device turns
                    PassFace {
                        dev: ticket
                        opacity: room.page === "pass" ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        now: tick.date
                        keys: room.buffer.length
                        busy: room.busy
                        wrong: room.verdict === "wrong"
                        done: room.verdict === "ok"
                        pulse: pulse.level
                        status: room.verdict === "ok" ? "BOARDING"
                            : room.busy ? "CHECKING"
                            : room.verdict === "wrong" ? "ACCESS DENIED"
                            : room.buffer === "" ? "ENTER ACCESS KEY" : "READY TO BOARD"
                    }
                    PowerFace {
                        dev: ticket
                        opacity: room.page === "power" ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        options: room.powerOptions
                        sel: room.powerSel
                        going: room.powerGoing
                        onChose: i => room.choosePower(i)
                        onConfirmed: room.confirmPower()
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
                Keys.onPressed: e => {
                    room.wake();
                    e.accepted = false;
                    if (room.page !== "power") return;
                    // the power face: choose and confirm; Esc (or typing) back to the key
                    switch (e.key) {
                    case Qt.Key_Up: case Qt.Key_Left: room.choosePower(room.powerSel - 1); break;
                    case Qt.Key_Down: case Qt.Key_Right: room.choosePower(room.powerSel + 1); break;
                    case Qt.Key_Return: case Qt.Key_Enter: room.confirmPower(); break;
                    case Qt.Key_Escape: if (!room.powerGoing) room.page = "pass"; break;
                    case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: case Qt.Key_5: room.choosePower(e.key - Qt.Key_1); break;
                    default:
                        if (e.text !== "" && !room.powerGoing) room.page = "pass";   // a key typed: the pass, and it goes in
                        return;
                    }
                    e.accepted = true;
                }
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
