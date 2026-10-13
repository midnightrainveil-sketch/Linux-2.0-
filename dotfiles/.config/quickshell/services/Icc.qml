pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The focused screen's colour profile, through archive-icc: the profiles it
// can find (~/.local/share/icc, ~/Downloads, /usr/share/color/icc) and the
// one in use. cycle() steps through None and each of them.
Singleton {
    id: root

    property var profiles: []           // file paths
    property string current: "none"     // a file path, or "none"
    readonly property string name: current === "none" ? "None" : current.split("/").pop().replace(/\.(icc|icm)$/i, "")

    function refresh(): void {
        lister.running = true;
        reader.running = true;
    }

    function cycle(step: int): void {
        const all = ["none"].concat(root.profiles);
        let i = all.indexOf(root.current);
        if (i < 0) i = 0;
        const next = all[(i + step + all.length) % all.length];
        writer.command = next === "none" ? ["archive-icc", "off"] : ["archive-icc", "set", next];
        writer.running = true;
        root.current = next;
    }

    Process {
        id: lister
        command: ["archive-icc", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.profiles = text.split("\n").filter(l => l.length > 0)
        }
    }

    Process {
        id: reader
        command: ["archive-icc", "current"]
        stdout: StdioCollector {
            onStreamFinished: root.current = text.trim() || "none"
        }
    }

    Process {
        id: writer
        onExited: reader.running = true
    }

    Component.onCompleted: refresh()
}
