pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The research station's sessions (widgets/typewriter): each question asked
// is a session, with its answer (a Wikipedia article in sections, through
// ultra-research), its sources, your notes on it, and how far you have read.
// Kept in ~/.local/state/ultra/retro-futurism/research.json.
//
//   sessions   [{ id, n, query, title, url, sections, sources, notes, read, created, error }]
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
        const s = { id: Date.now().toString(36), n: next, query: q, title: "", url: "", sections: [], sources: [],
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
    function setRead(p: real): void {
        if (current && p > (current.read ?? 0) + 0.004) patch(current.id, { read: Math.min(1, p) });
    }
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
                root.patch(asker.sid, {
                    title: d.title ?? "", url: d.url ?? "", sections: d.sections ?? [], sources: d.sources ?? [],
                    error: d.error ?? ""
                });
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
