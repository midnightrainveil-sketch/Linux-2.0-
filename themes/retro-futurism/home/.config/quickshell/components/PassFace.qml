import QtQuick
import qs.services

// The Kairo device's pass face (art/Login1.png): the Personal Access Pass,
// who you are, today, a dot for each key of the password typed, what it is
// doing, the ticket number. The lock screen shows it, and the power widget
// (◀◀ / ▶▶ turn the device from its power face to this and back). Drawn in
// the mock-up's pixels: put it inside a PassDevice (it glows with the rest
// of the face).
Item {
    id: face

    required property var dev                  // the PassDevice it is on
    property date now: new Date()
    property string user: Settings.user
    property int keys: 0                       // keys typed
    property bool busy: false                  // checking (the dots pulse)
    property bool wrong: false                 // the key was wrong (the line shakes)
    property bool done: false                  // let in (no cursor)
    property string status: "ENTER ACCESS KEY"
    property real pulse: 1                     // the dots' and the lamp's light while busy
    property string from: "LOCK\nSCREEN"      // the journey: here to the desk, or (the power widget) the desk to the lock
    property string to: "DESKTOP\nSESSION"

    width: 1162; height: 1201

    component Glow: Text {
        color: "#f2f8ff"
        font.family: "Barlow"
        font.weight: Font.Medium
    }
    component Rule: Rectangle { height: 3; color: "#f2f8ff"; opacity: 0.92 }

    // header: the mark, マグネティック88
    Canvas {
        x: face.dev.ax(193); y: face.dev.ay(188); width: 154; height: 48
        onPaint: {
            const c = getContext("2d"); c.reset(); c.fillStyle = face.dev.ink;
            const bar = (y, x0, x1, h) => { c.beginPath(); c.moveTo(x0 + 14, y); c.lineTo(x1 + 14, y); c.lineTo(x1, y + h); c.lineTo(x0, y + h); c.closePath(); c.fill(); };
            bar(0, 52, 152, 12);           // the mark: a cassette's E, leaning
            bar(18, 26, 128, 12);
            bar(36, 0, 140, 12);
            c.beginPath(); c.moveTo(70, 0); c.lineTo(84, 0); c.lineTo(56, 48); c.lineTo(42, 48); c.closePath(); c.fill();
        }
    }
    Rectangle { x: face.dev.ax(375); y: face.dev.ay(194); width: 3; height: 40; color: face.dev.ink }
    Glow { x: face.dev.ax(410); y: face.dev.ay(192); text: "マグネティック88"; font.pixelSize: 34; font.letterSpacing: 6 }

    Glow { x: face.dev.ax(184); y: face.dev.ay(262); text: "PERSONAL ACCESS PASS"; font.pixelSize: 48; font.weight: Font.DemiBold; font.letterSpacing: 2.9 }
    Glow { x: face.dev.ax(186); y: face.dev.ay(328); text: "ELECTRONIC BOARDING TICKET"; font.pixelSize: 25; font.letterSpacing: 6.4 }
    Rule { x: face.dev.ax(187); y: face.dev.ay(377); width: 526 }
    Repeater {
        model: 3
        Rectangle {
            required property int index
            x: face.dev.ax(733 + index * 21); y: face.dev.ay(366); width: 9; height: 15; color: face.dev.ink
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, 9, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
    }

    // passenger
    Glow { x: face.dev.ax(186); y: face.dev.ay(424); text: "PASSENGER"; font.pixelSize: 25; font.letterSpacing: 6 }
    Canvas {
        x: face.dev.ax(196); y: face.dev.ay(474); width: 52; height: 54
        onPaint: {
            const c = getContext("2d"); c.reset(); c.fillStyle = face.dev.ink;
            c.beginPath(); c.arc(26, 15, 14, 0, Math.PI * 2); c.fill();
            c.beginPath(); c.moveTo(0, 54); c.lineTo(0, 46); c.bezierCurveTo(0, 33, 12, 30, 26, 30);
            c.bezierCurveTo(40, 30, 52, 33, 52, 46); c.lineTo(52, 54); c.closePath(); c.fill();
        }
    }
    Glow {
        x: face.dev.ax(274); y: face.dev.ay(464); width: 500; elide: Text.ElideRight
        text: face.user; font.pixelSize: 52; font.letterSpacing: 1.4
    }
    Rule { x: face.dev.ax(187); y: face.dev.ay(554); width: 579 }

    // from the lock screen to the desk
    Glow { x: face.dev.ax(190); y: face.dev.ay(584); text: "FROM"; font.pixelSize: 25; font.letterSpacing: 6 }
    Glow { x: face.dev.ax(538); y: face.dev.ay(584); text: "TO"; font.pixelSize: 25; font.letterSpacing: 6 }
    Glow { x: face.dev.ax(192); y: face.dev.ay(616); text: face.from; font.pixelSize: 42; font.weight: Font.DemiBold; font.letterSpacing: 0.7; lineHeight: 0.98 }
    Glow { x: face.dev.ax(538); y: face.dev.ay(616); text: face.to; font.pixelSize: 42; font.weight: Font.DemiBold; font.letterSpacing: 0.7; lineHeight: 0.98 }
    Canvas {
        x: face.dev.ax(413); y: face.dev.ay(634); width: 66; height: 30
        onPaint: {
            const c = getContext("2d"); c.reset(); c.strokeStyle = face.dev.ink; c.lineWidth = 3.2; c.lineCap = "round";
            c.beginPath(); c.moveTo(2, 15); c.lineTo(62, 15); c.moveTo(48, 3); c.lineTo(62, 15); c.lineTo(48, 27); c.stroke();
        }
    }
    Rule { x: face.dev.ax(187); y: face.dev.ay(734); width: 579 }

    // today
    Canvas {
        x: face.dev.ax(195); y: face.dev.ay(765); width: 42; height: 42
        onPaint: {
            const c = getContext("2d"); c.reset(); c.strokeStyle = face.dev.ink; c.fillStyle = face.dev.ink; c.lineWidth = 3;
            c.strokeRect(2, 6, 38, 34); c.fillRect(2, 6, 38, 9);
            c.fillRect(9, 0, 4, 10); c.fillRect(29, 0, 4, 10);
            for (const [a, b] of [[9, 21], [19, 21], [29, 21], [9, 30], [19, 30]]) c.fillRect(a, b, 5, 5);
        }
    }
    readonly property var monthsUp: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    Glow {
        x: face.dev.ax(270); y: face.dev.ay(760)
        text: face.now.getDate() + " " + face.monthsUp[face.now.getMonth()] + " " + face.now.getFullYear()
        font.pixelSize: 40; font.letterSpacing: 0.4
        font.features: { "tnum": 1 }
    }
    Rectangle { x: face.dev.ax(532); y: face.dev.ay(765); width: 3; height: 41; color: face.dev.ink }
    Canvas {
        x: face.dev.ax(577); y: face.dev.ay(764); width: 44; height: 44
        onPaint: {
            const c = getContext("2d"); c.reset(); c.strokeStyle = face.dev.ink; c.lineWidth = 3.2; c.lineCap = "round";
            c.beginPath(); c.arc(22, 22, 19, 0, Math.PI * 2); c.stroke();
            c.beginPath(); c.moveTo(22, 10); c.lineTo(22, 23); c.lineTo(31, 28); c.stroke();
        }
    }
    Glow {
        x: face.dev.ax(651); y: face.dev.ay(760)
        text: Qt.formatTime(face.now, "hh:mm")
        font.pixelSize: 40; font.letterSpacing: 0.4
        font.features: { "tnum": 1 }
    }
    Rule { x: face.dev.ax(187); y: face.dev.ay(841); width: 593 }

    // the access key: a dot for each key, the cursor after them
    Glow { x: face.dev.ax(192); y: face.dev.ay(873); text: "ACCESS KEY"; font.pixelSize: 25; font.letterSpacing: 6 }
    Item {
        id: keyLine
        x: face.dev.ax(247); y: face.dev.ay(950)
        readonly property int shown: Math.min(face.keys, 10)
        Repeater {
            model: keyLine.shown
            Rectangle {
                required property int index
                x: index * 52.2 - 13; y: -13
                width: 26; height: 26; radius: 13
                color: face.dev.ink
                opacity: face.busy ? face.pulse : 1
                scale: 1
                Component.onCompleted: popIn.start()
                NumberAnimation on scale { id: popIn; from: 0.4; to: 1; duration: 120; easing.type: Easing.OutBack; running: false }
            }
        }
        Rectangle {
            // the cursor
            x: keyLine.shown === 0 ? -14 : (keyLine.shown - 1) * 52.2 + 36
            y: -34; width: 4; height: 64
            color: face.dev.ink
            visible: !face.busy && !face.done
            opacity: face.now.getSeconds() % 2 === 0 ? 1 : 0.15
        }
        // a wrong key: the line shakes
        SequentialAnimation on x {
            running: face.wrong
            NumberAnimation { to: face.dev.ax(247) - 14; duration: 50 }
            NumberAnimation { to: face.dev.ax(247) + 14; duration: 70 }
            NumberAnimation { to: face.dev.ax(247) - 9; duration: 70 }
            NumberAnimation { to: face.dev.ax(247); duration: 60 }
        }
    }
    Rule { x: face.dev.ax(191); y: face.dev.ay(999); width: 590 }

    // what it is doing
    Rectangle {
        x: face.dev.ax(198); y: face.dev.ay(1065); width: 30; height: 30; radius: 15
        color: face.wrong ? "transparent" : face.dev.ink
        border.width: 3; border.color: face.dev.ink
        opacity: face.busy ? face.pulse : 1
    }
    Glow {
        x: face.dev.ax(261); y: face.dev.ay(1060); width: 400
        font.pixelSize: 33; font.letterSpacing: 3
        text: face.status
    }
    Rectangle { x: face.dev.ax(678); y: face.dev.ay(1046); width: 3; height: 57; color: face.dev.ink }
    Glow { x: face.dev.ax(733); y: face.dev.ay(1042); text: "TKT No."; font.pixelSize: 25; font.letterSpacing: 3 }
    Glow {
        x: face.dev.ax(733); y: face.dev.ay(1070)
        // a ticket number of your own: from your name
        text: {
            let h = 7;
            for (const ch of face.user) h = (h * 31 + ch.charCodeAt(0)) % 1000000;
            return "M88-" + String(h).padStart(6, "0");
        }
        font.pixelSize: 26; font.letterSpacing: 3
    }
    Repeater {
        model: 3
        Rectangle {
            required property int index
            x: face.dev.ax(1022 + index * 30); y: face.dev.ay(1053); width: 14; height: 40; color: face.dev.ink
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.55, 0, 22, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
    }
}
