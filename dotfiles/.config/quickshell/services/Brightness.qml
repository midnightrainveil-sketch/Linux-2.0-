pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight through brightnessctl (works on the G14's amdgpu_bl*).
Singleton {
    id: root

    property int percent: 50
    signal changed()

    function step(delta: int): void {
        set(percent + delta);
    }

    function set(p: int): void {
        p = Math.max(1, Math.min(100, p));
        writer.command = ["brightnessctl", "-q", "-e4", "-n2", "set", p + "%"];
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

    // brightnessctl -m -> "amdgpu_bl1,backlight,128,50%,255"
    Process {
        id: reader
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length >= 4) root.percent = parseInt(parts[3]);
            }
        }
    }

    Component.onCompleted: refresh()
}
