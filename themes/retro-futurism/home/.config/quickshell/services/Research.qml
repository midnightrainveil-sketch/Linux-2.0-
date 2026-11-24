pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The research station's sessions (widgets/typewriter): each question asked
// is a session, with the web's results for it (through ultra-research), the
// ones you have opened, and your notes on it.
// Kept in ~/.local/state/ultra/retro-futurism/research.json.
//
//   sessions   [{ id, n, query, results: [{ title, url, site, snippet }], visited: [url], notes, read, created, error }]
//   openResult(r)   in the browser (and counted as read)
//   current    the session on the screen (or null)
//   ask(q)     a new session, looked up; busy while it is
//   exportCurrent()   to ~/Documents/Research (exported: its path)
Singleton {
    id: root

    property var sessions: []
    property int next: 1
    property string currentId: ""
    readonly property var current: sessions.find(s => s.id === currentId) ?? null
    property bool busy: false
    property string exported: ""
    property bool exporting: false
    property int rev: 0

    function open(id: string): void { currentId = id; exported = ""; }
    function ask(q: string): void {
        q = q.trim();
        if (q === "" || busy) return;
        const s = { id: Date.now().toString(36), n: next, query: q, results: [], visited: [],
                    notes: "", read: 0, created: Date.now(), error: "" };
        next += 1;
        sessions = [s].concat(sessions).slice(0, 60);
        currentId = s.id;
        exported = "";
        busy = true;
        asker.sid = s.id;
        asker.command = ["ultra-research", "ask", q];
        asker.running = true;
        changed();
    }
    function patch(id: string, ch: var): void {
        sessions = sessions.map(s => s.id === id ? Object.assign({}, s, ch) : s);
        changed();
    }
    function setNotes(text: string): void { if (current) patch(current.id, { notes: text }); }
    // a result opened in the browser: read (the progress is how many of the
    // first ten have been)
    function openResult(r: var): void {
        if (!r) return;
        Qt.openUrlExternally(r.url);
        const c = current;
        if (!c) return;
        const v = (c.visited ?? []).includes(r.url) ? c.visited : (c.visited ?? []).concat([r.url]);
        const top = (c.results ?? []).slice(0, 10).map(x => x.url);
        patch(c.id, { visited: v, read: top.length ? Math.min(1, top.filter(u => v.includes(u)).length / Math.min(5, top.length)) : 0 });
    }
    function visited(url: string): bool { return (current?.visited ?? []).includes(url); }
    function remove(id: string): void {
        sessions = sessions.filter(s => s.id !== id);
        if (currentId === id) currentId = sessions.length ? sessions[0].id : "";
        changed();
    }
    function exportCurrent(): void {
        if (!current || exporting) return;
        save.stop(); writeNow();
        exported = "";
        exporting = true;
        exporter.command = ["ultra-research", "export", current.id];
        // (written to disk first: the helper reads the session from there)
        exportLater.restart();
    }
    Timer { id: exportLater; interval: 250; onTriggered: exporter.running = true }

    Process {
        id: asker
        property string sid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d) d = { error: "The look-up failed." };
                root.patch(asker.sid, { results: d.results ?? [], error: d.error ?? "" });
                root.busy = false;
            }
        }
        onExited: code => { if (code !== 0 && root.busy) { root.patch(asker.sid, { error: "ultra-research is missing or failed." }); root.busy = false; } }
    }
    Process {
        id: exporter
        stdout: StdioCollector {
            onStreamFinished: { root.exported = text.trim(); root.exporting = false; }
        }
        onExited: code => { if (code !== 0) { root.exported = ""; root.exporting = false; } }
    }

    // ---- kept
    function changed(): void { rev++; save.restart(); }
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ultra/retro-futurism/research.json"
    function writeNow(): void { store.setText(JSON.stringify({ next: root.next, sessions: root.sessions })); }
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.sessions = (d.sessions ?? []).filter(s => s && s.id);
                root.next = Math.max(d.next ?? 1, ...root.sessions.map(s => (s.n ?? 0) + 1), 1);
                if (root.sessions.length && !root.currentId) root.currentId = root.sessions[0].id;
            } catch (e) {}
            root.rev++;
        }
    }
    Timer { id: save; interval: 600; onTriggered: root.writeNow() }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.file.replace(/\/[^/]*$/, "")])
}
