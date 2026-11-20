pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through ultra-brightness: the panel's backlight, or,
// when an OLED ignores it, software dimming through hyprsunset.
Singleton {
    id: root

    property int percent: 50
    signal changed()

    function step(delta: int): void {
        set(percent + delta);
    }

    // A drag asks for many values in a moment: the newest waits while one
    // is being written, and the ones between are skipped. What the machine
    // says back is read only once it has gone quiet, so an answer to an
    // older value never pulls the figure back.
    property int pending: -1
    function set(p: int): void {
        p = Math.max(1, Math.min(100, p));
        root.percent = p;
        root.changed();
        quiet.restart();
        if (writer.running) { pending = p; return; }
        write(p);
    }
    function write(p: int): void {
        writer.command = ["ultra-brightness", "set", String(p)];
        writer.running = true;
    }

    function refresh(): void { if (!writer.running && pending < 0 && !quiet.running) reader.running = true; }

    Process {
        id: writer
        onExited: {
            if (root.pending >= 0) { const p = root.pending; root.pending = -1; root.write(p); }
        }
    }
    Timer { id: quiet; interval: 900; onTriggered: root.refresh() }

    // ultra-brightness get -> "50"
    Process {
        id: reader
        command: ["ultra-brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.trim());
                if (!isNaN(p) && !writer.running && root.pending < 0 && !quiet.running) root.percent = p;
            }
        }
    }

    Component.onCompleted: refresh()
}
