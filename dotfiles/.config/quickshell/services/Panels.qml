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
    // one, which says ready() once it is there. It is then drawn once,
    // unseen (each card's window is shown, the card all but transparent,
    // while it is `preparing`), and says drawn() when that frame is on
    // screen; it opens a moment later. Opened at once, its first frame
    // (the window mapped, its pictures and shadows made) would take the
    // opening animation's time, and the card would appear already open.
    // Closed, it is kept a moment for its closing animation, then let go
    // (gone()).
    readonly property var onDemand: ["typewriter", "phonograph", "notebook", "ledger-year", "clippings", "keys", "glyphs"]
    property string preparing: ""
    property string lingering: ""
    property var built: ({})
    function wanted(name: string): bool { return open === name || preparing === name || lingering === name; }
    function ready(name: string): void {
        const b = Object.assign({}, built); b[name] = true; built = b;
        if (preparing === name) warm.restart();
    }
    function drawn(name: string): void {
        if (preparing === name && !settle.running) settle.restart();
    }
    function gone(name: string): void {
        const b = Object.assign({}, built); delete b[name]; built = b;
    }
    function openPrepared(): void {
        warm.stop();
        settle.stop();
        const name = preparing;
        if (name === "") return;
        open = name;                    // (it stays wanted: open now holds it)
        preparing = "";
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
    // after its first frame, a moment for the pictures loading beside it
    Timer { id: settle; interval: 60; onTriggered: root.openPrepared() }
    // in case no frame is reported
    Timer { id: warm; interval: 1200; onTriggered: root.openPrepared() }

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
