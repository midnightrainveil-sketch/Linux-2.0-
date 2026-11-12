pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The notes: ~/.config/ultra/viewfinder/notes.txt, one a line, "[x] done"
// or "[ ] to do". Tick one on the desk, or open the file to write them.
Singleton {
    id: root
    property var items: []           // [{ done, text }]
    readonly property string path: Settings.own + "/notes.txt"

    function parse(text: string): void {
        const out = [];
        for (const raw of text.split("\n")) {
            const m = raw.match(/^\s*\[( |x|X)\]\s*(.*)$/);
            if (m) out.push({ done: m[1] !== " ", text: m[2] });
            else if (raw.trim() !== "") out.push({ done: false, text: raw.trim() });
        }
        items = out;
    }
    function toggle(i: int): void {
        const out = items.slice();
        if (!out[i]) return;
        out[i] = { done: !out[i].done, text: out[i].text };
        items = out;
        file.setText(out.map(n => (n.done ? "[x] " : "[ ] ") + n.text).join("\n") + "\n");
    }
    function edit(): void { Quickshell.execDetached(["ultra-notes"]); }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(file.text())
        onLoadFailed: root.items = []
    }
}
