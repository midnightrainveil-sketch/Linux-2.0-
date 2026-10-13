pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through archive-brightness: the panel's backlight, or,
// when an OLED ignores it, software dimming through hyprsunset.
Singleton {
    id: root

    property int percent: 50
    signal changed()

    function step(delta: int): void {
        set(percent + delta);
    }

    function set(p: int): void {
        p = Math.max(1, Math.min(100, p));
        writer.command = ["archive-brightness", "set", String(p)];
        writer.running = true;
        root.percent = p;
        root.changed();
        Sounds.play("volume");
    }

    function refresh(): void { reader.running = true; }

    Process {
        id: writer
        onExited: root.refresh()
    }

    // archive-brightness get -> "50"
    Process {
        id: reader
        command: ["archive-brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.trim());
                if (!isNaN(p)) root.percent = p;
            }
        }
    }

    Component.onCompleted: refresh()
}
