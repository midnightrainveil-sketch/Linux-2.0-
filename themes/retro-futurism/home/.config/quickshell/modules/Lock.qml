import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services
import qs.components

// The lock screen: the room at night, asleep under the headphones. The
// Botsync clock on the night stand keeps the time and the date; the rest
// of the picture is still. The password is typed unseen, then Enter.
// Lock with:  qs ipc call lock lock (Super + Escape and the idle timer do this.)
//
// The picture is ~/.local/share/ultra/retro-futurism/lock.jpg: the scene
// with the clock's window left empty (made from art/Lockscreen.png). The live parts are placed in the picture's own
// pixels (1671 x 941), so they stay on it at any screen size.
Scope {
    id: room

    property string buffer: ""
    property string verdict: ""        // "", "ok", "wrong"
    property bool busy: false

    function lock() {
        if (sessionLock.locked) return;
        buffer = "";
        verdict = "";
        sessionLock.locked = true;
    }
    function submit() {
        if (busy || buffer.length === 0) return;
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
                unlockLater.start();
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
    // a check that never answers must not leave the line dead: after ten
    // seconds it takes typing again
    Timer {
        interval: 10000
        running: room.busy
        onTriggered: { room.busy = false; room.buffer = ""; room.verdict = "wrong"; }
    }
    Timer { id: unlockLater; interval: 350; onTriggered: { sessionLock.locked = false; room.buffer = ""; room.verdict = ""; } }

    // the clock: ticks every second, only while locked
    SystemClock { id: tick; precision: SystemClock.Seconds; enabled: sessionLock.locked }

    WlSessionLock {
        id: sessionLock
        locked: false
        // tell the system the session is locked (logind's LockedHint): the
        // machine's commands that must not act under the lock read it
        // (ultra-refresh, ultra-health wake)
        onLockedChanged: Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
            "SetLockedHint", "b", locked ? "true" : "false"])

        WlSessionLockSurface {
            id: surface
            color: "#1a120e"

            // ---- the picture, cropped to fill the screen; px() / py() put a
            // point of the picture on the screen
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

            MouseArea { anchors.fill: parent; onPressed: field.forceActiveFocus() }

            // ---- the Botsync DC-80: time and date
            readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
            readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

            SevenSegment {
                // the clock's window: 100,634 to 254,711 in the picture,
                // turned a little, as the clock stands
                x: surface.px(100); y: surface.py(634)
                width: 154 * surface.k; height: 77 * surface.k
                rotation: -1.3
                visible: picture.status === Image.Ready
                text: Qt.formatTime(tick.date, "hh:mm")
                colon: tick.date.getSeconds() % 2 === 0
            }
            DotMatrix {
                // the date strip: 114,723 to 218,740
                x: surface.px(114); y: surface.py(723)
                width: 104 * surface.k; height: 17 * surface.k
                rotation: -1.0
                unit: surface.k
                pitch: 1.45
                visible: picture.status === Image.Ready
                text: surface.days[tick.date.getDay()] + " " + tick.date.getDate() + " " + surface.months[tick.date.getMonth()]
            }

            // ---- the password: typed unseen, Enter to unlock
            TextInput {
                id: field
                width: 1; height: 1
                opacity: 0
                focus: true
                echoMode: TextInput.Password
                cursorDelegate: Item {}
                // read-only, not disabled, while it checks: a disabled
                // field drops the keyboard and never takes it back
                readOnly: room.busy || room.verdict === "ok"
                onTextChanged: room.buffer = text
                onAccepted: room.submit()
                Keys.onEscapePressed: room.buffer = ""
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
                    function onBufferChanged() { if (room.buffer === "" && field.text !== "") field.text = ""; }
                }
            }
        }
    }
}
