import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Power (art/Power.png): the Kairo device again (components/PassDevice),
// with what to do now on its face. Comes up when the laptop's power button
// is pressed (held, it still shuts down at once: ultra-boot power), from the
// Arch logo on the taskbar, or Super + Shift + Escape.
//
//   choosing   the wheel (mouse or touchpad: the roller turns with it), the
//              arrow keys, 1-5, or a click on a line
//   doing      Enter / Space, the roller, or a click on the chosen line
//   shortcuts  ‖ suspend · POWER shut down · USER log out · SESSION lock
//              (each only chooses; the roller or Enter does it)
//   faces      ◀◀ / ▶▶ (or Tab) turn the device to its pass, as on the lock
//              screen (components/PassFace.qml): Enter or a click there locks
//   layout     SAVE (or S) notes the windows open and where they are;
//              RESTORE (or R) opens them again after a login (ultra-layout;
//              logging out saves by itself)
// Restart and shut down light the red lamp. It always opens on Suspend.
Widget {
    id: self
    widgetId: "power"

    readonly property real k: 0.6
    preferredWidth: 1162 * k
    preferredHeight: 1201 * k

    readonly property var options: [
        { word: "LOCK",      doing: "LOCKING",       icon: "lock" },
        { word: "SUSPEND",   doing: "SUSPENDING",    icon: "moon" },
        { word: "LOG OUT",   doing: "LOGGING OUT",   icon: "exit" },
        { word: "RESTART",   doing: "RESTARTING",    icon: "again" },
        { word: "SHUT DOWN", doing: "SHUTTING DOWN", icon: "power" }
    ]
    property int sel: 1
    // the device's two faces: "power" and "pass" (◀◀ / ▶▶ turn it)
    property string page: "power"
    property date now: new Date()
    Timer { interval: 1000; running: self.page === "pass"; repeat: true; triggeredOnStart: true; onTriggered: self.now = new Date() }
    function flip(): void { if (!going) page = page === "power" ? "pass" : "power"; }
    function show(i: int): void { if (going) return; page = "power"; choose(i); }
    property bool going: false                                 // chosen and on its way

    function choose(i: int, rolled: bool): void {
        if (going) return;
        const n = Math.max(0, Math.min(options.length - 1, i));
        if (n === sel) return;
        if (!rolled) kairo.roll(n - sel);           // (the wheel has turned the roller already)
        sel = n;
    }
    function move(d: int): void { choose(sel + d); }

    // ---- the windows across a logout (ultra-layout)
    property string note: ""                                   // said on the face a moment
    Timer { id: noteTimer; interval: 2600; onTriggered: self.note = "" }
    function say(text: string): void { note = text; noteTimer.restart(); }
    function saveLayout(): void {
        if (going || saver.running) return;
        say("SAVING LAYOUT…");
        saver.running = true;
    }
    function restoreLayout(): void {
        if (going) return;
        Widgets.close();
        Quickshell.execDetached(["ultra-layout", "restore"]);
    }
    Process {
        id: saver
        command: ["ultra-layout", "save"]
        // (how many windows it noted: "ultra-layout: noted 3 programs, 5 windows")
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(\d+) windows/);
                if (m) self.say("SAVED: " + m[1] + " WINDOW" + (m[1] === "1" ? "" : "S"));
            }
        }
        onExited: (code, status) => { if (code !== 0) self.say("COULD NOT SAVE"); }
    }
    function confirm(): void {
        if (going) return;
        going = true;
        if (page === "pass") lockIt.start();
        else doIt.start();
    }
    Timer { id: lockIt; interval: 420; onTriggered: { Widgets.close(); Scene.lockNow(); } }
    // a moment to read what it is doing, then do it
    Timer {
        id: doIt
        interval: 420
        onTriggered: {
            switch (self.sel) {
            case 0: Widgets.close(); Scene.lockNow(); break;
            case 1: Widgets.close(); Quickshell.execDetached(["systemctl", "suspend"]); break;
            case 2: Quickshell.execDetached(["ultra-session", "logout"]); break;
            case 3: Quickshell.execDetached(["systemctl", "reboot"]); break;
            case 4: Quickshell.execDetached(["systemctl", "poweroff"]); break;
            }
        }
    }

    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Tab: case Qt.Key_Backtab: flip(); break;
        case Qt.Key_Up: case Qt.Key_Left: case Qt.Key_K: if (page === "power") move(-1); else flip(); break;
        case Qt.Key_Down: case Qt.Key_Right: case Qt.Key_J: if (page === "power") move(1); else flip(); break;
        case Qt.Key_Home: choose(0); break;
        case Qt.Key_End: choose(options.length - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: confirm(); break;
        case Qt.Key_S: saveLayout(); break;
        case Qt.Key_R: restoreLayout(); break;
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: case Qt.Key_5: show(e.key - Qt.Key_1); break;
        default: return;
        }
        e.accepted = true;
    }

    PassDevice {
        id: kairo
        scale: self.k
        transformOrigin: Item.TopLeft
        forwardIsEnter: false
        lamp: self.page === "power" && self.sel >= 3          // restart, shut down
        onRolled: steps => { if (self.page === "power") self.choose(self.sel + steps, true); }
        onBack: self.flip()                                     // ◀◀ ▶▶: the other face
        onForward: self.flip()
        onEnter: self.confirm()
        onPause: self.show(1)
        onPower: self.show(4)
        onUser: self.show(2)
        onSession: self.show(0)

        PowerFace {
            dev: kairo
            opacity: self.page === "power" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }
            options: self.options
            sel: self.sel
            going: self.going
            note: self.note
            onChose: i => self.choose(i)
            onConfirmed: self.confirm()
        }
        // the pass, as on the lock screen: who you are, today; Enter locks
        PassFace {
            dev: kairo
            opacity: self.page === "pass" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }
            now: self.now
            status: self.going ? "LOCKING…" : "ENTER TO LOCK"
            from: "DESKTOP\nSESSION"
            to: "LOCK\nSCREEN"
            done: true                                           // (no key to type here: no cursor)
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: self.confirm() }
        }
    }

    // ---- SAVE and RESTORE: two more of the device's buttons, under the
    // roller, as its USER and SESSION are (the button taken from its own
    // picture; the label engraved in the metal)
    Item {
        width: kairo.width; height: kairo.height
        scale: self.k
        transformOrigin: Item.TopLeft

        component Engraved: Text {
            color: "#3b3a39"
            style: Text.Raised
            styleColor: "#fbfaf9"
            font.family: "Barlow"
            font.weight: Font.Bold
            font.pixelSize: 25
            font.letterSpacing: 1.5
        }
        component Key: Item {
            id: key
            property string label: ""
            signal hit()
            width: 150; height: 104
            Engraved { anchors.horizontalCenter: parent.horizontalCenter; y: 0; text: key.label }
            Image {
                // (SESSION's button, bezel and all, cut from the picture with
                // soft edges by tools/make_pass.py)
                y: 40; width: 150; height: 54
                source: Quickshell.shellPath("assets/pass-key.png")
                smooth: true
                Rectangle {
                    x: 7; y: 7; width: 136; height: 38; radius: 19
                    color: "#1d2024"
                    opacity: area.pressed ? 0.22 : area.containsMouse ? 0.07 : 0
                    Behavior on opacity { NumberAnimation { duration: 70 } }
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: key.hit()
            }
        }

        Key { x: kairo.ax(890); y: kairo.ay(790); label: "SAVE"; onHit: self.saveLayout() }
        Key { x: kairo.ax(890); y: kairo.ay(895); label: "RESTORE"; onHit: self.restoreLayout() }
    }
}
