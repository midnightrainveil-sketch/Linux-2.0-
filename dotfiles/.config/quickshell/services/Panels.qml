pragma Singleton

import QtQuick
import Quickshell

// Which shell surface is open. Only one popup card at a time, like a desk
// where you only read one record at once.
Singleton {
    id: root

    // "", "catalogue", "ledger", "ledger-year", "instrument", "disposition",
    // "register", "phonograph", "notebook", "typewriter"
    property string open: ""

    // the month the Ledger opens at next, in months from this one (set by
    // the year's ledger when a month is picked there; read once)
    property int ledgerAt: 0

    function toggle(name: string): void { if (open === name) open = ""; else show(name); }
    function show(name: string): void {
        // a card built only while it is used: build it first, open it next
        if (onDemand.indexOf(name) >= 0 && !built[name]) { preparing = name; return; }
        open = name;
    }
    function close(): void { open = ""; }

    // The cards used now and then (shell.qml) are built only while open, so
    // their pictures and drawing are not kept between uses: show() builds
    // one, which says ready() once it is there, and opens a moment later
    // (so it opens as it always has); closed, it is kept a moment for its
    // closing animation, then let go (gone()).
    readonly property var onDemand: ["typewriter", "phonograph", "notebook", "ledger-year"]
    property string preparing: ""
    property string lingering: ""
    property var built: ({})
    function wanted(name: string): bool { return open === name || preparing === name || lingering === name; }
    function ready(name: string): void {
        const b = Object.assign({}, built); b[name] = true; built = b;
        if (preparing === name) Qt.callLater(() => { if (root.preparing === name) { root.preparing = ""; root.open = name; } });
    }
    function gone(name: string): void {
        const b = Object.assign({}, built); delete b[name]; built = b;
    }
    property string was: ""
    onOpenChanged: {
        if (was !== "" && was !== open && onDemand.indexOf(was) >= 0) {
            lingering = was;
            linger.restart();
        }
        was = open;
    }
    Timer { id: linger; interval: 1500; onTriggered: root.lingering = "" }

    // a quick press of the power button (PowerHold): Disposition asks to
    // shut down, and a second press says yes
    property int powerSerial: 0
    function powerKey(): void { powerSerial += 1; }

    // Instrument reading (OSD): "volume" | "brightness" | "keyboard"
    property string osdKind: ""
    property int osdSerial: 0
    function osd(kind: string): void {
        osdKind = kind;
        osdSerial += 1;
    }

}
