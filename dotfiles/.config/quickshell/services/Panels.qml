pragma Singleton

import QtQuick
import Quickshell

// Which shell surface is open. Only one popup card at a time, like a desk
// where you only read one record at once.
Singleton {
    id: root

    // "", "catalogue", "ledger", "instrument", "disposition"
    property string open: ""

    function toggle(name: string): void { open = (open === name) ? "" : name; }
    function show(name: string): void { open = name; }
    function close(): void { open = ""; }

    // Instrument reading (OSD): "volume" | "brightness" | "keyboard"
    property string osdKind: ""
    property int osdSerial: 0
    function osd(kind: string): void {
        osdKind = kind;
        osdSerial += 1;
    }

}
