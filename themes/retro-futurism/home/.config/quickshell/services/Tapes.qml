pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The cassettes and their player, for the vending machine (widgets/vending)
// and the cassette player (widgets/cassette). The cassettes are the audio
// files in ~/Music, one each (ultra-tapes library); the player is a
// windowless mpv, started on the first play and spoken to over its socket.
//
// A cassette is "in" the player once dispensed (loaded); it plays, pauses,
// winds, and comes out again with eject.
Singleton {
    id: root

    readonly property string sock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ultra-tapes.sock"

    // ---------------------------------------------------------------- the cassettes
    property var tapes: []           // [{ file, title, artist, album, year, track, length, cover, shell }]
    property string musicRoot: ""
    property bool reading: false
    property bool readOnce: false

    function read(): void {
        reconnect();
        if (lister.running) return;
        reading = true;
        lister.running = true;
    }
    Process {
        id: lister
        command: ["ultra-tapes", "library", Settings.get("music", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.tapes = d.tapes ?? [];
                    root.musicRoot = d.root ?? "";
                } catch (e) {
                    console.warn("tapes: could not read the library:", e);
                }
                root.reading = false;
                root.readOnce = true;
            }
        }
        onExited: code => { if (code !== 0) { root.reading = false; root.readOnce = true; } }
    }
    function search(q: string): var {
        q = q.trim().toLowerCase();
        if (q === "") return tapes;
        return tapes.filter(t => (t.title + " " + t.artist + " " + t.album).toLowerCase().includes(q));
    }

    // ---------------------------------------------------------------- what is in the player
    // the cassette in the player (dispensed and not ejected), or null
    property var tape: null
    property bool paused: true
    property bool idle: true
    property bool ended: false
    property real position: 0
    property real duration: 0
    property int volume: 100
    property string path: ""
    // winding: -1 rewinding, 1 fast-forwarding, 0 not (the reels race)
    property int winding: 0

    readonly property bool connected: socket.connected
    readonly property bool loaded: tape !== null
    readonly property bool playing: loaded && connected && !idle && !paused && !ended
    readonly property real length: duration > 0 ? duration : (tape?.length ?? 0)
    // how far the tape has run, 0..1 (the reels' spools follow it)
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function time(s: real): string {
        if (!isFinite(s) || s < 0) s = 0;
        const m = Math.floor(s / 60), r = Math.floor(s % 60);
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // a cassette in, at its start: playing, or (start false) waiting for PLAY
    function insert(t: var, start: bool): void {
        if (!t) return;
        tape = t;
        ended = false;
        position = 0;
        duration = t.length || 0;
        const go = start !== false;
        send(["set_property", "pause", !go]);
        send(["loadfile", t.file, "replace"]);
        paused = !go;
    }
    // set by the vending machine as it hands a cassette over: the player,
    // opening, shows it going in (and then presses PLAY)
    property bool fresh: false
    function play(): void {
        if (!loaded) return;
        if (ended || idle || path !== tape.file) { insert(tape, true); return; }
        send(["set_property", "pause", false]);
    }
    function pause(): void { if (loaded) send(["set_property", "pause", true]); }
    function toggle(): void { if (playing) pause(); else play(); }
    // stop: the tape halts where it is (play goes on from there)
    function stop(): void { winding = 0; pause(); }
    // out: stopped, and the cassette gone from the player
    function eject(): void {
        winding = 0;
        send(["stop"]);
        tape = null;
        position = 0;
        duration = 0;
    }
    function seekTo(s: real): void { if (loaded) send(["seek", Math.max(0, s), "absolute"]); }
    function seekBy(s: real): void { if (loaded) { ended = false; send(["seek", s, "relative"]); } }
    function setVolume(v: int): void { send(["set_property", "volume", Math.max(0, Math.min(130, v))]); }

    // winding while REW / FF is held: the tape runs on in jumps, a little
    // faster the longer it is held
    property real windHeld: 0
    function wind(dir: int): void { if (!loaded) return; winding = dir; windHeld = 0; windTick.restart(); }
    function unwind(): void { winding = 0; windTick.stop(); }
    Timer {
        id: windTick
        interval: 120
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.winding === 0) { stop(); return; }
            root.windHeld += interval / 1000;
            const step = root.winding * Math.min(12, 2 + root.windHeld * 4);
            root.seekBy(step);
            root.position = Math.max(0, Math.min(root.length, root.position + step));
        }
    }

    // ---------------------------------------------------------------- speaking to mpv
    property var queue: []
    function send(cmd): void {
        const line = JSON.stringify({ command: cmd }) + "\n";
        if (socket.connected) {
            socket.write(line);
            socket.flush();
        } else {
            queue.push(line);
            start();
        }
    }
    function start(): void {
        if (socket.connected || retry.running) return;
        Quickshell.execDetached(["ultra-tapes", "start"]);
        retry.tries = 0;
        retry.restart();
    }
    Timer {
        id: retry
        property int tries: 0
        interval: 250
        repeat: true
        onTriggered: {
            if (socket.connected || ++tries > 40) { stop(); return; }
            socket.connected = true;
        }
    }
    // a player already running (the shell restarted) is taken up
    function reconnect(): void { if (!socket.connected && !retry.running) finder.running = true; }
    Process {
        id: finder
        running: true
        command: ["test", "-S", root.sock]
        onExited: code => { if (code === 0) socket.connected = true; }
    }

    Socket {
        id: socket
        path: root.sock
        onConnectedChanged: {
            if (!connected) { root.idle = true; return; }
            const watch = ["pause", "idle-active", "duration", "path", "volume", "eof-reached"];
            watch.forEach((p, i) => write(JSON.stringify({ command: ["observe_property", i + 1, p] }) + "\n"));
            for (const l of root.queue) write(l);
            root.queue = [];
            flush();
        }
        parser: SplitParser {
            onRead: line => {
                let m;
                try { m = JSON.parse(line); } catch (e) { return; }
                if (m.event === "property-change") {
                    const v = m.data;
                    switch (m.name) {
                    case "pause": root.paused = !!v; break;
                    case "idle-active": root.idle = !!v; break;
                    case "duration": if (v) root.duration = v; break;
                    case "path": root.path = v ?? ""; break;
                    case "volume": root.volume = Math.round(v ?? 100); break;
                    // the tape has run out: it stays in, wound to its end
                    case "eof-reached": root.ended = !!v; if (v) root.position = root.length; break;
                    }
                } else if (m.request_id === 100 && m.error === "success") {
                    if (root.winding === 0) root.position = m.data ?? 0;
                }
            }
        }
    }
    // the position, a few times a second while it plays and someone looks
    property int watchers: 0
    Timer {
        running: socket.connected && root.loaded && root.watchers > 0
        interval: 250
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            socket.write(JSON.stringify({ command: ["get_property", "time-pos"], request_id: 100 }) + "\n");
            socket.flush();
        }
    }
}
