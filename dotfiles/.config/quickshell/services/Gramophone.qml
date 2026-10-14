pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The gramophone's records and its player. The records are the folders in
// ~/Music (archive-gramophone library: one album per folder, with tags and
// sleeves); the player is a windowless mpv, started on the first play and
// spoken to over its socket. With mpv-mpris installed it is also an
// ordinary media player (media keys, the Audio Archive card).
Singleton {
    id: root

    readonly property string sock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/archive-gramophone.sock"

    // ---------------------------------------------------------------- the records
    property var albums: []
    property string musicRoot: ""
    property bool reading: false
    property bool readOnce: false

    function readLibrary(): void {
        reconnect();
        if (lister.running) return;
        reading = true;
        lister.running = true;
    }
    Process {
        id: lister
        command: ["archive-gramophone", "library", Settings.get("music", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.albums = d.albums ?? [];
                    root.musicRoot = d.root ?? "";
                } catch (e) {
                    console.warn("gramophone: could not read the library:", e);
                }
                root.reading = false;
                root.readOnce = true;
            }
        }
        onExited: code => { if (code !== 0) { root.reading = false; root.readOnce = true; } }
    }

    // ---------------------------------------------------------------- the player's state
    property bool paused: true
    property bool idle: true
    property real position: 0
    property real duration: 0
    property int volume: 100
    property string path: ""

    readonly property bool connected: socket.connected
    readonly property bool loaded: connected && !idle && path !== ""
    readonly property bool playing: loaded && !paused

    // where the playing file is filed: its album and track
    readonly property int albumIndex: {
        if (path === "") return -1;
        for (let i = 0; i < albums.length; i++)
            if (albums[i].tracks.some(t => t.file === path)) return i;
        return -1;
    }
    readonly property var album: albumIndex >= 0 ? albums[albumIndex] : null
    readonly property int trackIndex: album ? album.tracks.findIndex(t => t.file === path) : -1
    readonly property var track: album && trackIndex >= 0 ? album.tracks[trackIndex] : null

    // how far through the whole record (all its tracks), 0..1: where the
    // needle is
    readonly property real albumProgress: {
        if (!album || trackIndex < 0) return duration > 0 ? Math.min(1, position / duration) : 0;
        let total = 0, before = 0;
        album.tracks.forEach((t, i) => { const l = t.length || 0; total += l; if (i < trackIndex) before += l; });
        return total > 0 ? Math.min(1, (before + position) / total) : 0;
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

    // the player, started if it is not already
    function start(): void {
        if (socket.connected || retry.running) return;
        Quickshell.execDetached(["archive-gramophone", "start"]);
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

    // at login, and whenever the gramophone is opened: a player already
    // running (the shell restarted, or it was started elsewhere) is taken up
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
            if (!connected) { root.idle = true; root.path = ""; return; }
            const watch = ["pause", "idle-active", "duration", "path", "volume"];
            watch.forEach((p, i) => write(JSON.stringify({ command: ["observe_property", i + 1, p] }) + "\n"));
            for (const l of root.queue) write(l);
            root.queue = [];
            flush();
        }
        parser: SplitParser {
            onRead: line => {
                let m;
                try { m = JSON.parse(line); } catch (e) { return; }
                if (m.event === "file-loaded" && root.pendingSeek >= 0) {
                    root.send(["seek", root.pendingSeek, "absolute"]);
                    root.pendingSeek = -1;
                } else if (m.event === "property-change") {
                    const v = m.data;
                    switch (m.name) {
                    case "pause": root.paused = !!v; break;
                    case "idle-active": root.idle = !!v; if (v) { root.path = ""; root.position = 0; } break;
                    case "duration": root.duration = v ?? 0; break;
                    case "path": root.path = v ?? ""; root.position = 0; break;
                    case "volume": root.volume = Math.round(v ?? 100); break;
                    }
                } else if (m.request_id === 100 && m.error === "success") {
                    root.position = m.data ?? 0;
                }
            }
        }
    }

    // the position, asked for while something is listening (time-pos would
    // otherwise arrive dozens of times a second)
    property int watchers: 0
    Timer {
        running: socket.connected && root.loaded && root.watchers > 0
        interval: 400
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            socket.write(JSON.stringify({ command: ["get_property", "time-pos"], request_id: 100 }) + "\n");
            socket.flush();
        }
    }

    // ---------------------------------------------------------------- what the gramophone does
    // put album a on, from track t
    function play(a: int, t: int): void {
        const al = albums[a];
        if (!al) return;
        if (a === albumIndex && t >= 0) {
            send(["playlist-play-index", t]);
            send(["set_property", "pause", false]);
            return;
        }
        send(["stop"]);
        for (const tr of al.tracks) send(["loadfile", tr.file, "append"]);
        send(["playlist-play-index", Math.max(0, t)]);
        send(["set_property", "pause", false]);
    }
    function toggle(): void { if (loaded) send(["cycle", "pause"]); }
    function next(): void { if (loaded) send(["playlist-next"]); }
    function previous(): void {
        if (!loaded) return;
        // back to the start of this track first, as a record player would
        if (position > 4) send(["seek", 0, "absolute"]);
        else send(["playlist-prev"]);
    }
    function seek(by: real): void { if (loaded) send(["seek", by, "relative"]); }
    // drop the needle at a point on the record (0..1 of the whole album)
    function setNeedle(f: real): void {
        if (!album) { if (loaded) send(["seek", f * 100, "absolute-percent"]); return; }
        let total = 0;
        album.tracks.forEach(t => total += t.length || 0);
        let at = f * total;
        for (let i = 0; i < album.tracks.length; i++) {
            const l = album.tracks[i].length || 0;
            if (at <= l || i === album.tracks.length - 1) {
                if (i === trackIndex) {
                    send(["seek", Math.max(0, at), "absolute"]);
                } else {
                    // a fresh track can only be wound on once it has opened
                    pendingSeek = Math.max(0, at);
                    send(["playlist-play-index", i]);
                }
                return;
            }
            at -= l;
        }
    }
    property real pendingSeek: -1

    // put album a on with the needle at f (0..1 across the whole record)
    function playAt(a: int, f: real): void {
        const al = albums[a];
        if (!al) return;
        if (a === albumIndex) { setNeedle(f); return; }
        let total = 0;
        al.tracks.forEach(t => total += t.length || 0);
        let at = f * total, i = 0;
        for (; i < al.tracks.length - 1; i++) {
            const l = al.tracks[i].length || 0;
            if (at <= l) break;
            at -= l;
        }
        if (at > 1) pendingSeek = at;
        play(a, i);
    }
    function setVolume(v: int): void { send(["set_property", "volume", Math.max(0, Math.min(130, v))]); }
    function stop(): void { send(["stop"]); }
}
