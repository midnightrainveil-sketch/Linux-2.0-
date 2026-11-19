pragma Singleton

import QtQuick
import Quickshell

// Which sheet is open: "", "launcher", "power", "themes". One at a time.
Singleton {
    property string open: ""
    function toggle(name: string): void { open = open === name ? "" : name; }
    function close(): void { open = ""; }
    // where the notification cards begin (under the notes; set by the backdrop)
    property real mailY: 560
}
