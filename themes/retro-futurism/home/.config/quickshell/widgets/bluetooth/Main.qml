import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Bluetooth: the devices it knows and the ones in reach, on an e-ink screen
// in a chrome rim (components/ChromePanel). Opened from the control deck's
// BLUETOOTH line.
//
//   choosing   Up / Down or the pointer; a line lights up (inverted)
//   Enter      or a click: connect it (a new one is paired and trusted
//              first); one connected: disconnect it
//   S          look for devices in reach (SCAN, ten seconds)
//   Esc        back to the deck
//
// BlueZ does the work (bluetoothctl); the list is read again every few
// seconds while it is up.
Widget {
    id: self
    widgetId: "bluetooth"
    preferredWidth: 660
    preferredHeight: 620

    readonly property color ink: "#2a2c2a"
    readonly property color glass: "#bcbcbb"

    // ---- the devices: [{ mac, name, paired, connected }]
    property var devices: []
    property int sel: 0
    property string status: ""
    property bool busy: false
    readonly property bool scanning: scanner.running

    function parse(text: string): void {
        const parts = text.split("\n--\n");
        const read = s => (s ?? "").split("\n").map(l => l.match(/^Device ([0-9A-F:]{17}) ?(.*)$/i)).filter(m => m);
        const paired = new Set(read(parts[1]).map(m => m[1]));
        const connected = new Set(read(parts[2]).map(m => m[1]));
        const list = read(parts[0]).map(m => ({
            mac: m[1], name: m[2] && m[2] !== m[1].replace(/:/g, "-") ? m[2] : m[1],
            paired: paired.has(m[1]), connected: connected.has(m[1])
        }));
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
        const was = devices[sel]?.mac;
        devices = list;
        const i = list.findIndex(d => d.mac === was);
        sel = i >= 0 ? i : Math.min(sel, Math.max(0, list.length - 1));
    }
    function refresh(): void {
        if (lister.running) return;
        lister.running = true;
    }
    Process {
        id: lister
        command: ["sh", "-c", "bluetoothctl devices 2>/dev/null; printf '\\n--\\n'; bluetoothctl devices Paired 2>/dev/null; printf '\\n--\\n'; bluetoothctl devices Connected 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: self.parse(text) }
    }
    Process {
        id: scanner
        command: ["bluetoothctl", "--timeout", "10", "scan", "on"]
        onExited: self.refresh()
    }
    function scan(): void { if (Net.bluetoothOn && !scanner.running) scanner.running = true; }
    Timer { interval: 3000; running: self.shown && !self.busy; repeat: true; onTriggered: self.refresh() }
    onOpened: { refresh(); scan(); }

    function act(d: var): void {
        if (!d || busy) return;
        busy = true;
        if (d.connected) {
            status = "DISCONNECTING…";
            doer.command = ["bluetoothctl", "disconnect", d.mac];
        } else if (d.paired) {
            status = "CONNECTING…";
            doer.command = ["bluetoothctl", "connect", d.mac];
        } else {
            status = "PAIRING…";
            doer.command = ["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"", "sh", d.mac];
        }
        doer.running = true;
    }
    Process {
        id: doer
        stdout: StdioCollector { id: doerOut }
        onExited: (code, st) => {
            self.busy = false;
            self.status = code === 0 && !/Failed|not available|Error/i.test(doerOut.text) ? "DONE" : "DID NOT WORK";
            clearStatus.restart();
            self.refresh();
        }
    }
    Timer { id: clearStatus; interval: 4000; onTriggered: self.status = "" }

    escapeHandler: () => { Widgets.open("controls"); return true; }
    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Up: case Qt.Key_K: sel = Math.max(0, sel - 1); break;
        case Qt.Key_Down: case Qt.Key_J: sel = Math.min(devices.length - 1, sel + 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: act(devices[sel]); break;
        case Qt.Key_S: scan(); break;
        default: return;
        }
        e.accepted = true;
    }

    // ======================================================================
    ChromePanel {
        anchors.fill: parent

        component Ink: Text {
            color: "#2a2c2a"
            font.family: "VT323"
            font.pixelSize: 34
            style: Text.Raised; styleColor: Qt.rgba(0.16, 0.17, 0.16, 0.07)
        }

        // header: /// BLUETOOTH      SCAN
        Row {
            spacing: 16
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    y: 8; width: 9; height: 24; color: self.ink
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.5, 0, 12, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
            Item { width: 10; height: 1 }
            Ink { text: "BLUETOOTH"; font.pixelSize: 44 }
        }
        Item {
            visible: Net.bluetoothOn
            anchors.right: parent.right; y: 2; width: scanText.width + 20; height: 38
            Rectangle { anchors.fill: parent; color: self.ink; opacity: scanArea.containsMouse || self.scanning ? 1 : 0 }
            Ink {
                id: scanText
                anchors.centerIn: parent
                text: self.scanning ? "SCANNING" : "SCAN"
                color: scanArea.containsMouse || self.scanning ? self.glass : self.ink
            }
            MouseArea { id: scanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: self.scan() }
        }
        Rectangle { y: 50; width: parent.width; height: 2.5; color: self.ink }

        Ink {
            y: 58; width: parent.width; elide: Text.ElideRight
            font.pixelSize: 30
            text: !Net.bluetoothAvailable ? "NO BLUETOOTH HERE"
                : !Net.bluetoothOn ? "BLUETOOTH IS OFF"
                : self.status !== "" ? self.status
                : Net.bluetoothConnected > 0 ? Net.bluetoothConnected + " CONNECTED"
                : "NOTHING CONNECTED"
        }

        // ---- off: a line to turn it on
        Item {
            visible: Net.bluetoothAvailable && !Net.bluetoothOn
            y: 120; width: parent.width; height: 46
            Rectangle { anchors.fill: parent; color: self.ink; opacity: onArea.containsMouse ? 1 : 0 }
            Ink { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "TURN BLUETOOTH ON"; color: onArea.containsMouse ? self.glass : self.ink }
            MouseArea { id: onArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Net.setBluetooth(true) }
        }

        ListView {
            id: list
            visible: Net.bluetoothOn
            y: 104; width: parent.width; height: parent.height - 104 - 44
            clip: true
            model: self.devices
            currentIndex: self.sel
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Item {
                id: line
                required property var modelData
                required property int index
                readonly property bool lit: index === self.sel
                width: list.width; height: 46
                Rectangle { anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 2; color: self.ink; opacity: line.lit ? 1 : 0 }
                // a dot: full when connected, a ring when paired, nothing when only in reach
                Rectangle {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8
                    visible: line.modelData.connected || line.modelData.paired
                    color: line.modelData.connected ? (line.lit ? self.glass : self.ink) : "transparent"
                    border.width: 2.5; border.color: line.lit ? self.glass : self.ink
                }
                Ink {
                    x: 44; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44 - 150; elide: Text.ElideRight
                    text: line.modelData.name
                    color: line.lit ? self.glass : self.ink
                }
                Ink {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 28
                    text: line.modelData.connected ? "CONNECTED" : line.modelData.paired ? "PAIRED" : "NEW"
                    color: line.lit ? self.glass : self.ink
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: self.sel = line.index
                    onClicked: self.act(line.modelData)
                }
            }
            Ink {
                visible: self.devices.length === 0
                y: 10; x: 10; font.pixelSize: 30
                text: self.scanning ? "LOOKING…" : "NO DEVICES YET: SCAN"
            }
        }

        Rectangle { y: parent.height - 38; width: parent.width; height: 2.5; color: self.ink }
        Ink {
            y: parent.height - 32; font.pixelSize: 26
            text: "ENTER CONNECT · S SCAN · ESC BACK"
        }
    }
}
