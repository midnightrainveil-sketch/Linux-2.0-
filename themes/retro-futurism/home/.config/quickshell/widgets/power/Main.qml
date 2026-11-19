import QtQuick
import Quickshell
import qs.components
import qs.services

// Power (art/Power.png): the Kasetto device again (components/PassDevice),
// with what to do now on its face. Comes up when the laptop's power button
// is pressed (held, it still shuts down at once: ultra-boot power), from the
// Arch logo on the taskbar, or Super + Shift + Escape.
//
//   choosing   the wheel (mouse or touchpad: the roller turns with it), the
//              arrow keys, ◀◀ / ▶▶ on the device, 1-5, or a click on a line
//   doing      Enter / Space, the roller, or a click on the chosen line
//   shortcuts  ‖ suspend · POWER shut down · USER log out · SESSION lock
//              (each only chooses; the roller or Enter does it)
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
    readonly property var rowY: [450, 557, 662, 767, 874]    // each line's middle, in the mock-up
    property int sel: 1
    property bool going: false                                 // chosen and on its way

    function choose(i: int): void {
        if (going) return;
        const n = Math.max(0, Math.min(options.length - 1, i));
        if (n === sel) return;
        dev.roll(n - sel);
        sel = n;
    }
    function move(d: int): void { choose(sel + d); }
    function confirm(): void {
        if (going) return;
        going = true;
        doIt.start();
    }
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
        case Qt.Key_Up: case Qt.Key_Left: case Qt.Key_K: move(-1); break;
        case Qt.Key_Down: case Qt.Key_Right: case Qt.Key_J: move(1); break;
        case Qt.Key_Home: choose(0); break;
        case Qt.Key_End: choose(options.length - 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: confirm(); break;
        case Qt.Key_1: case Qt.Key_2: case Qt.Key_3: case Qt.Key_4: case Qt.Key_5: choose(e.key - Qt.Key_1); break;
        default: return;
        }
        e.accepted = true;
    }

    PassDevice {
        id: dev
        scale: self.k
        transformOrigin: Item.TopLeft
        forwardIsEnter: false
        lamp: self.sel >= 3                                // restart, shut down
        onRolled: steps => self.choose(self.sel + steps)   // (the roller has turned already)
        onBack: self.move(-1)
        onForward: self.move(1)
        onEnter: self.confirm()
        onPause: self.choose(1)
        onPower: self.choose(4)
        onUser: self.choose(2)
        onSession: self.choose(0)

        component Glow: Text {
            color: dev.ink
            font.family: "Barlow"
            font.weight: Font.Medium
        }
        component Rule: Rectangle { height: 3; color: dev.ink; opacity: 0.92 }
        component Slashes: Repeater {
            id: sl
            property real x0: 0
            property real y0: 0
            property real h: 16
            model: 3
            Rectangle {
                required property int index
                x: sl.x0 + index * sl.h * 1.45; y: sl.y0; width: sl.h * 0.6; height: sl.h; color: dev.ink
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, sl.h * 0.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
            }
        }

        // ---- an icon, drawn: lock, moon, exit, again, power
        component Icon: Canvas {
            id: ic
            property string name: ""
            property real stroke: 6
            width: 56; height: 56
            onNameChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset();
                c.strokeStyle = dev.ink; c.fillStyle = dev.ink;
                c.lineWidth = ic.stroke; c.lineCap = "round"; c.lineJoin = "round";
                switch (ic.name) {
                case "lock":
                    c.beginPath(); c.arc(28, 22, 11, Math.PI, 0); c.lineTo(39, 27); c.moveTo(17, 27); c.lineTo(17, 22); c.stroke();
                    c.fillRect(10, 26, 36, 27);
                    c.globalCompositeOperation = "destination-out";
                    c.beginPath(); c.arc(28, 36, 4.5, 0, Math.PI * 2); c.fill(); c.fillRect(26, 37, 4, 9);
                    break;
                case "moon":
                    c.beginPath(); c.arc(28, 28, 22, 0, Math.PI * 2); c.fill();
                    c.globalCompositeOperation = "destination-out";
                    c.beginPath(); c.arc(40, 18, 20, 0, Math.PI * 2); c.fill();
                    break;
                case "exit":
                    c.beginPath(); c.moveTo(30, 8); c.lineTo(48, 8); c.lineTo(48, 48); c.lineTo(30, 48); c.stroke();
                    c.beginPath(); c.moveTo(6, 28); c.lineTo(34, 28); c.moveTo(24, 18); c.lineTo(34, 28); c.lineTo(24, 38); c.stroke();
                    break;
                case "again":
                    c.beginPath(); c.arc(28, 28, 18, Math.PI * 1.1, Math.PI * 1.85); c.stroke();
                    c.beginPath(); c.arc(28, 28, 18, Math.PI * 0.1, Math.PI * 0.85); c.stroke();
                    c.beginPath(); c.moveTo(44, 6); c.lineTo(45, 18); c.lineTo(33, 17); c.stroke();
                    c.beginPath(); c.moveTo(12, 50); c.lineTo(11, 38); c.lineTo(23, 39); c.stroke();
                    break;
                case "power":
                    c.beginPath(); c.arc(28, 30, 19, -Math.PI * 0.32, Math.PI * 1.32); c.stroke();
                    c.beginPath(); c.moveTo(28, 6); c.lineTo(28, 28); c.stroke();
                    break;
                }
            }
        }

        // ---- header: ⏻ | ///, SYSTEM CONTROL, POWER MANAGEMENT
        Icon { x: dev.X(203); y: dev.Y(179); name: "power"; stroke: 4.6 }
        Rectangle { x: dev.X(298); y: dev.Y(188); width: 3; height: 39; color: dev.ink }
        Slashes { x0: dev.X(333); y0: dev.Y(197); h: 19 }
        Glow { x: dev.X(191); y: dev.Y(250); text: "SYSTEM CONTROL"; font.pixelSize: 56; font.weight: Font.DemiBold; font.letterSpacing: 7.6 }
        Glow { x: dev.X(192); y: dev.Y(318); text: "POWER MANAGEMENT"; font.pixelSize: 26; font.letterSpacing: 13.4 }
        Rule { x: dev.X(191); y: dev.Y(373); width: 501 }
        Slashes { x0: dev.X(708); y0: dev.Y(362); h: 16 }

        // ---- the five lines
        Repeater {
            model: self.options
            Item {
                id: line
                required property var modelData
                required property int index
                readonly property bool chosen: index === self.sel
                x: dev.X(207); y: dev.Y(self.rowY[index] - 53)
                width: 487; height: 106
                opacity: chosen ? 1 : 0.78
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Icon {
                    x: 270 - 207 - 28; y: 53 - 28
                    name: line.modelData.icon
                }
                Glow {
                    x: 350 - 207; y: 53 - height / 2
                    text: line.modelData.word
                    font.pixelSize: 44
                    font.weight: line.chosen ? Font.Bold : Font.DemiBold
                    font.letterSpacing: 7
                }
                Rule { x: 0; y: 53 + 52; width: 487; opacity: 0.85 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: line.chosen ? self.confirm() : self.choose(line.index)
                }
            }
        }
        // the marks either side of the chosen line, gliding with it
        Item {
            id: marks
            x: 0; y: dev.Y(self.rowY[self.sel])
            Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Canvas {
                x: dev.X(193); y: -10; width: 20; height: 20
                onPaint: { const c = getContext("2d"); c.reset(); c.fillStyle = dev.ink; c.beginPath(); c.moveTo(0, 0); c.lineTo(18, 10); c.lineTo(0, 20); c.closePath(); c.fill(); }
            }
            Canvas {
                x: dev.X(688); y: -10; width: 20; height: 20
                onPaint: { const c = getContext("2d"); c.reset(); c.fillStyle = dev.ink; c.beginPath(); c.moveTo(20, 0); c.lineTo(2, 10); c.lineTo(20, 20); c.closePath(); c.fill(); }
            }
            // and a faint band behind it
            Rectangle {
                x: dev.X(207); y: -50; width: 487; height: 100
                color: dev.ink; opacity: 0.06
            }
        }

        // ---- what is chosen, and how to do it
        Rule { x: dev.X(193); y: dev.Y(1001); width: 591 }
        Glow {
            x: dev.X(196); y: dev.Y(1022)
            text: self.going ? self.options[self.sel].doing + "…" : "SELECTED: " + self.options[self.sel].word
            font.pixelSize: 30; font.letterSpacing: 4.2
        }
        Glow {
            x: dev.X(196); y: dev.Y(1066)
            text: self.going ? "" : "ENTER TO CONFIRM"
            font.pixelSize: 24; font.letterSpacing: 6.6
        }
        Slashes { x0: dev.X(703); y0: dev.Y(1033); h: 28 }
    }
}
