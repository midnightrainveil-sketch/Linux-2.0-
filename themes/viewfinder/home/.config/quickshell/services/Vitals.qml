pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Processor load, memory in use and temperature, read every three seconds
// by one small script (ultra-vitals) that stays running.
Singleton {
    id: root
    property int cpu: 0              // percent
    property real memory: 0          // GiB in use
    property int memoryPercent: 0
    property int temperature: 0      // °C, 0 when the machine does not say

    Process {
        running: true
        command: ["ultra-vitals"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim().split(/\s+/);
                if (p.length < 4) return;
                root.cpu = parseInt(p[0]) || 0;
                root.memory = parseFloat(p[1]) || 0;
                root.memoryPercent = parseInt(p[2]) || 0;
                root.temperature = parseInt(p[3]) || 0;
            }
        }
    }
}
