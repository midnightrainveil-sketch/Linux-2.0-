import QtQuick
import Quickshell
import qs.components
import qs.services

// The clock (art/ClockWidget.png): the Suisei DC-80. Comes up in the middle
// of the screen, the desk blurred behind (Super + W, or click the taskbar's
// time). Its alarm and timer are services/Alarms.qml: they go on with the
// clock put away, and ring whatever is on the screen.
//
//   MODE (M, Tab, or a lamp)   TIME / ALARM / TIMER
//   ALARM lamp (A), again      the alarm on / off (the strip says which; its
//                              lamp stays faintly lit while it is on)
//   SET  (S, Enter)            TIME: set the alarm. ALARM: hour, then minute,
//                              then done (and the alarm on). TIMER: minutes,
//                              then seconds, then done.
//   the date strip (Space)     ALARM: on / off too. TIMER: start / pause.
//   Up / Down, the wheel       the figure being set; the wheel over either
//                              pair of digits sets that pair
//   Backspace, R               TIMER: back to its set time
//   Esc                        leave the setting; again, put the clock away
//   ringing                    any key or click stops it; MODE (or Z) snoozes
//                              the alarm 9 minutes
//
// Its pictures are made from the mock-up by tools/make_clock.py; everything
// is placed in the mock-up's own pixels (clock.png starts at its 79, 104)
// and the whole clock scaled once.
Widget {
    id: self
    widgetId: "clock"

    readonly property real k: 0.62
    preferredWidth: 1425 * k
    preferredHeight: 832 * k

    // ---- what it shows
    property int mode: 0                          // 0 TIME, 1 ALARM, 2 TIMER
    property string edit: ""                      // the pair being set: "h", "m" (alarm); "m", "s" (timer)
    readonly property string ringing: Alarms.ringing
    readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    function pad(n) { return (n < 10 ? "0" : "") + n; }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // a slow blink for what is being set, and for a ring
    property bool blink: true
    Timer {
        interval: 450; repeat: true
        running: self.edit !== "" || self.ringing !== ""
        onTriggered: self.blink = !self.blink
        onRunningChanged: self.blink = true
    }

    readonly property string pairs: {
        if (ringing !== "" && !blink) return "    ";
        let a, b;
        if (mode === 1 || ringing === "alarm") { a = pad(Alarms.alarmHour); b = pad(Alarms.alarmMinute); }
        else if (mode === 2 || ringing === "timer") {
            const left = self.edit !== "" ? Alarms.timerSet : Alarms.timerLeft;
            a = pad(Math.min(99, Math.floor(left / 60))); b = pad(left % 60);
        } else { a = pad(clock.date.getHours()); b = pad(clock.date.getMinutes()); }
        if (edit !== "" && !blink) {
            const first = edit === "h" || (mode === 2 && edit === "m");
            if (first) a = "  "; else b = "  ";
        }
        return a + b;
    }
    readonly property string strip: {
        if (ringing === "alarm") return blink ? "WAKE UP" : "";
        if (ringing === "timer") return blink ? "TIME UP" : "";
        const d = clock.date;
        if (mode === 0) {
            if ((Alarms.alarmOn || Alarms.snoozing) && d.getSeconds() % 10 >= 6)
                return Alarms.snoozing ? "SNOOZING" : "ALARM " + pad(Alarms.alarmHour) + ":" + pad(Alarms.alarmMinute);
            return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()];
        }
        if (mode === 1) {
            if (edit === "h") return "SET HOUR";
            if (edit === "m") return "SET MINUTE";
            return Alarms.snoozing ? "SNOOZING" : Alarms.alarmOn ? "ALARM ON" : "ALARM OFF";
        }
        if (edit === "m") return "SET MINUTES";
        if (edit === "s") return "SET SECONDS";
        if (Alarms.timerRunning) return "RUNNING";
        if (Alarms.timerPaused) return "PAUSED";
        return Alarms.timerSet > 0 ? "READY" : "SET TIMER";
    }

    // ---- what it does
    function setMode(m: int): void { mode = m; edit = ""; store.set("mode", m); }
    function nextMode(): void { setMode((mode + 1) % 3); }
    // a lamp pressed: its mode; ALARM pressed again: the alarm on or off
    function lamp(m: int): void {
        if (m === 1 && mode === 1 && edit === "") Alarms.toggleAlarm();
        else setMode(m);
    }
    function set(): void {
        if (mode === 0) { setMode(1); edit = "h"; return; }
        if (mode === 1) {
            if (edit === "") edit = "h";
            else if (edit === "h") edit = "m";
            else { edit = ""; if (!Alarms.alarmOn) Alarms.toggleAlarm(); }
            return;
        }
        if (edit === "") { Alarms.resetTimer(); edit = "m"; }
        else if (edit === "m") edit = "s";
        else edit = "";
    }
    function act(): void {
        edit = "";
        if (mode === 1) Alarms.toggleAlarm();
        else if (mode === 2) Alarms.toggleTimer();
    }
    // step the pair being set (or the pair given) by d
    function adjust(d: int, pair: string): void {
        const which = pair || edit;
        if (mode === 1) {
            if (which === "h") Alarms.setAlarm(Alarms.alarmHour + d, Alarms.alarmMinute);
            else if (which === "m") Alarms.setAlarm(Alarms.alarmHour, Alarms.alarmMinute + d);
        } else if (mode === 2) {
            if (Alarms.timerRunning || Alarms.timerPaused) Alarms.resetTimer();
            const m = Math.floor(Alarms.timerSet / 60), s = Alarms.timerSet % 60;
            if (which === "m") Alarms.setTimer(Math.max(0, Math.min(99, m + d)) * 60 + s);
            else if (which === "s") Alarms.setTimer(m * 60 + (s + d + 60) % 60);
        }
    }

    Component.onCompleted: {
        mode = store && store.ready ? store.get("mode", 0) : 0;
        if (ringing !== "") mode = ringing === "alarm" ? 1 : 2;
    }
    // its saved mode, once read (the store is the clock's own: it reads it
    // straight from 'store', which goes with the clock)
    Connections {
        target: store
        function onReadyChanged() { if (store && store.ready && ringing === "") mode = store.get("mode", 0); }
    }
    Connections {
        target: Alarms
        function onRingingChanged() { if (Alarms.ringing !== "") { self.edit = ""; self.mode = Alarms.ringing === "alarm" ? 1 : 2; } }
    }

    escapeHandler: () => {
        if (ringing !== "") { Alarms.stop(); return true; }
        if (edit !== "") { edit = ""; return true; }
        return false;
    }
    Keys.onPressed: e => {
        if (ringing !== "") {
            if (e.key === Qt.Key_M || e.key === Qt.Key_Z || e.key === Qt.Key_Tab) Alarms.snooze();
            else Alarms.stop();
            e.accepted = true;
            return;
        }
        switch (e.key) {
        case Qt.Key_M: case Qt.Key_Tab: nextMode(); break;
        case Qt.Key_S: case Qt.Key_Return: case Qt.Key_Enter: set(); break;
        case Qt.Key_Space: act(); break;
        case Qt.Key_Up: case Qt.Key_Plus: case Qt.Key_Equal: adjust(1, ""); break;
        case Qt.Key_Down: case Qt.Key_Minus: adjust(-1, ""); break;
        case Qt.Key_Backspace: case Qt.Key_R: if (mode === 2) { edit = ""; Alarms.resetTimer(); } break;
        case Qt.Key_T: setMode(0); break;
        case Qt.Key_A: lamp(1); break;
        default: return;
        }
        e.accepted = true;
    }

    // ======================================================================
    // the clock, in the mock-up's pixels
    Item {
        id: face
        width: 1425; height: 832
        scale: self.k
        transformOrigin: Item.TopLeft
        function ax(x) { return x - 79; }
        function ay(y) { return y - 104; }

        Image {
            anchors.fill: parent
            source: self.art("clock.png")
            smooth: true; mipmap: true
        }

        // ---- the digits (the glass 258-1162 x 288-620)
        SevenSegment {
            x: face.ax(330); y: face.ay(310)
            width: 800; height: 270
            cellW: 800; cellH: 270
            digitX: [30, 194, 446, 608]
            digitTop: 23; dw: 140; dh: 221; t: 25; tv: 32; miter: true; gap: 8; lean: 0.05
            colonX: 394.25; colonX2: 392.4; dotR: 14.5; dotSquare: true
            glowWide: 18; glowNear: 5
            lit: "#f7a030"; glow: "#ff8a1e"
            unlit: Qt.rgba(1, 0.6, 0.2, 0.035)
            relief: true
            text: self.pairs.slice(0, 2) + ":" + self.pairs.slice(2)
            colon: self.mode === 0 && self.ringing === "" ? clock.date.getSeconds() % 2 === 0
                 : self.ringing !== "" ? self.blink : true
        }
        // the two pairs: click to set one, the wheel to step it
        Repeater {
            model: [{ x: 340, w: 360, pair: 0 }, { x: 740, w: 360, pair: 1 }]
            MouseArea {
                required property var modelData
                x: face.ax(modelData.x); y: face.ay(320); width: modelData.w; height: 250
                enabled: self.mode !== 0 && self.ringing === ""
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                readonly property string pair: self.mode === 1 ? (modelData.pair === 0 ? "h" : "m")
                                                               : (modelData.pair === 0 ? "m" : "s")
                onClicked: {
                    if (self.mode === 2 && (Alarms.timerRunning || Alarms.timerPaused)) Alarms.resetTimer();
                    self.edit = pair;
                }
                onWheel: e => { self.edit = pair; self.adjust(e.angleDelta.y > 0 ? 1 : -1, pair); }
            }
        }

        // ---- the date strip (392-896 x 678-731): what it is doing; a click
        // turns the alarm on or off, starts or pauses the timer
        DotMatrix {
            x: face.ax(394); y: face.ay(679)
            width: 500; height: 52
            pitch: 6.8
            lit: "#ffae3a"; glow: "#ff8a1e"
            unlit: Qt.rgba(1, 0.62, 0.25, 0.05)
            text: self.strip
            MouseArea {
                anchors.fill: parent
                enabled: self.mode !== 0 && self.ringing === ""
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: self.act()
            }
        }

        // ---- the lamps: the mode lit; the alarm's and the timer's glow a
        // little while they are set or running in another mode; a click
        // chooses the mode
        Repeater {
            model: [349, 392.5, 434.5]
            Item {
                id: lampRow
                required property real modelData
                required property int index
                readonly property real level: {
                    if (self.ringing !== "" && index === (self.ringing === "alarm" ? 1 : 2)) return self.blink ? 1 : 0.15;
                    if (self.mode === index) return 1;
                    if (index === 1 && Alarms.alarmOn) return 0.35;
                    if (index === 2 && Alarms.timerRunning) return 0.35;
                    return 0;
                }
                x: face.ax(1218); y: face.ay(modelData - 22); width: 156; height: 44
                Image {
                    x: face.ax(1222) - lampRow.x; y: face.ay(modelData - 16) - lampRow.y
                    source: self.art("lamp-lit.png")
                    opacity: lampRow.level
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // (ALARM, when it is already showing: the alarm on / off)
                    onClicked: if (self.ringing === "") self.lamp(lampRow.index)
                }
            }
        }

        // ---- SET and MODE (1050-1140 and 1167-1252, y 683-738)
        component Button: Item {
            id: button
            signal hit()
            Rectangle {
                anchors.fill: parent; radius: 8
                color: "#2a1f15"
                opacity: area.pressed ? 0.28 : area.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: 70 } }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: button.hit()
            }
        }
        Button {
            x: face.ax(1050); y: face.ay(683); width: 90; height: 55
            onHit: self.ringing !== "" ? Alarms.stop() : self.set()
        }
        Button {
            x: face.ax(1167); y: face.ay(683); width: 85; height: 55
            onHit: self.ringing !== "" ? Alarms.snooze() : self.nextMode()
        }

        // ---- ringing: a click anywhere else on the clock stops it
        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: self.ringing !== ""
            onClicked: Alarms.stop()
        }
    }
}
