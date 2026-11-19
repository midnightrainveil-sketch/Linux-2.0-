pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The clock's alarm and timer. They live here, not in the clock widget, so
// they keep going while the clock is put away and ring whatever is on the
// screen: a sound every couple of seconds (for a minute and a half at
// most), a notification, and the clock brought up to stop or snooze them.
// Kept across restarts in ~/.local/state/ultra/retro-futurism/clock.json.
//
//   alarm   alarmOn, alarmHour, alarmMinute: rings every day at that time
//           setAlarm(h, m), toggleAlarm(); snooze() puts it off 9 minutes
//   timer   timerSet (seconds), timerLeft (seconds, live), timerRunning
//           setTimer(s), startTimer(), pauseTimer(), toggleTimer(), resetTimer()
//   ringing "", "alarm" or "timer"; stop()
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ultra/retro-futurism"
    readonly property string sound: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
    readonly property int snoozeMinutes: 9
    readonly property int ringSeconds: 90

    // ---- the alarm
    property bool alarmOn: false
    property int alarmHour: 7
    property int alarmMinute: 0
    property real snoozeUntil: 0                 // ms since the epoch, or 0
    readonly property bool snoozing: snoozeUntil > 0

    function setAlarm(h: int, m: int): void {
        alarmHour = ((h % 24) + 24) % 24;
        alarmMinute = ((m % 60) + 60) % 60;
        snoozeUntil = 0;
        save();
    }
    function toggleAlarm(): void { alarmOn = !alarmOn; snoozeUntil = 0; save(); }

    // ---- the timer
    property int timerSet: 300                    // seconds it is set to
    property real timerEnds: 0                    // while running: when it ends (ms)
    property real timerLeftMs: 300000             // while not running: what is left
    property real now: Date.now()                 // kept fresh while it runs
    readonly property bool timerRunning: timerEnds > 0
    readonly property int timerLeft: Math.max(0, Math.ceil((timerRunning ? timerEnds - now : timerLeftMs) / 1000))
    readonly property bool timerPaused: !timerRunning && timerLeftMs > 0 && timerLeftMs < timerSet * 1000

    function setTimer(seconds: int): void {
        timerSet = Math.max(0, Math.min(5999, seconds));    // 99:59 at most
        timerEnds = 0;
        timerLeftMs = timerSet * 1000;
        save();
    }
    function startTimer(): void {
        if (timerRunning) return;
        if (timerLeftMs <= 0) timerLeftMs = timerSet * 1000;
        if (timerLeftMs <= 0) return;
        now = Date.now();
        timerEnds = now + timerLeftMs;
        save();
    }
    function pauseTimer(): void {
        if (!timerRunning) return;
        timerLeftMs = Math.max(0, timerEnds - Date.now());
        timerEnds = 0;
        save();
    }
    function toggleTimer(): void { timerRunning ? pauseTimer() : startTimer(); }
    function resetTimer(): void { timerEnds = 0; timerLeftMs = timerSet * 1000; save(); }

    // ---- ringing
    property string ringing: ""
    property real ringSince: 0

    function ring(kind: string): void {
        ringing = kind;
        ringSince = Date.now();
        now = ringSince;
        Widgets.open("clock");
        Quickshell.execDetached(["notify-send", "--app-name=Clock", "--urgency=critical",
            kind === "alarm" ? "Alarm" : "Timer",
            kind === "alarm" ? pad(alarmHour) + ":" + pad(alarmMinute) : "Time is up"]);
    }
    function stop(): void {
        const was = ringing;
        ringing = "";
        if (was === "timer") resetTimer();
    }
    function snooze(): void {
        if (ringing !== "alarm") { stop(); return; }
        ringing = "";
        snoozeUntil = Date.now() + snoozeMinutes * 60000;
        save();
    }
    function pad(n: int): string { return (n < 10 ? "0" : "") + n; }

    // the sound, again and again while it rings
    Timer {
        interval: 2200; repeat: true; triggeredOnStart: true
        running: root.ringing !== ""
        onTriggered: Quickshell.execDetached(["pw-play", root.sound])
    }
    // the timer's second hand, and the end of a ring nobody stopped
    Timer {
        interval: 250; repeat: true
        running: root.timerRunning || root.ringing !== ""
        onTriggered: {
            root.now = Date.now();
            if (root.timerRunning && root.now >= root.timerEnds) {
                root.timerEnds = 0;
                root.timerLeftMs = 0;
                root.save();
                root.ring("timer");
            }
            if (root.ringing !== "" && root.now - root.ringSince > root.ringSeconds * 1000) root.stop();
        }
    }
    // the alarm: looked at as each minute begins
    property string firedAt: ""
    SystemClock {
        id: minute
        precision: SystemClock.Minutes
        onDateChanged: root.check()
    }
    function check(): void {
        if (!loaded) return;
        const d = minute.date;
        const at = d.toDateString() + " " + d.getHours() + ":" + d.getMinutes();
        if (alarmOn && d.getHours() === alarmHour && d.getMinutes() === alarmMinute && firedAt !== at) {
            firedAt = at;
            snoozeUntil = 0;
            ring("alarm");
        } else if (snoozing && Date.now() >= snoozeUntil) {
            snoozeUntil = 0;
            save();
            ring("alarm");
        }
    }

    // ---- kept across restarts
    property bool loaded: false
    function save(): void {
        if (!loaded) return;
        file.setText(JSON.stringify({
            alarmOn: alarmOn, alarmHour: alarmHour, alarmMinute: alarmMinute, snoozeUntil: snoozeUntil,
            timerSet: timerSet, timerEnds: timerEnds, timerLeftMs: timerLeftMs
        }, null, 2));
    }
    FileView {
        id: file
        path: root.stateDir + "/clock.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.alarmOn = d.alarmOn === true;
                root.alarmHour = d.alarmHour ?? 7;
                root.alarmMinute = d.alarmMinute ?? 0;
                root.snoozeUntil = d.snoozeUntil ?? 0;
                root.timerSet = d.timerSet ?? 300;
                root.timerLeftMs = d.timerLeftMs ?? root.timerSet * 1000;
                const ends = d.timerEnds ?? 0;
                const t = Date.now();
                // a timer that ended while the shell was not running: rung
                // if just now, else set back
                if (ends > 0 && ends <= t) {
                    root.timerEnds = 0; root.timerLeftMs = 0;
                    if (t - ends < 5 * 60000) ringLater.start(); else root.timerLeftMs = root.timerSet * 1000;
                } else {
                    root.timerEnds = ends;
                }
            } catch (e) {
                console.warn("clock: clock.json is not valid JSON:", e);
            }
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true          // none yet: the defaults
    }
    Timer { id: ringLater; interval: 1500; onTriggered: root.ring("timer") }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.stateDir])
}
