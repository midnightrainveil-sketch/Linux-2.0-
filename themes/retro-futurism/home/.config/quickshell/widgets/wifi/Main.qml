import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Wi-Fi: the networks in reach, on an e-ink screen in a chrome rim
// (components/ChromePanel). Opened from the control deck's WI-FI line.
//
//   choosing   Up / Down, the wheel, or the pointer; a line lights up (inverted)
//   Enter      or a click: join it (a saved one at once, an open one at once,
//              a locked new one asks for its key here); the one joined: leave it
//   S          look again for networks (SCAN)
//   Esc        back to the deck (typing a key: stop typing)
//
// NetworkManager does the work (nmcli); the list is read again every few
// seconds while it is up.
Widget {
    id: self
    widgetId: "wifi"
    preferredWidth: 660
    preferredHeight: 620

    readonly property color ink: "#2a2c2a"
    readonly property color glass: "#bcbcbb"
    readonly property string face: "VT323"

    // ---- the networks: [{ ssid, signal (0-100), secure, active, known }]
    property var networks: []
    property int sel: 0
    property string asking: ""            // the network whose key is being typed
    property string status: ""            // what it is doing / did
    property bool busy: false
    property bool scanning: false

    // nmcli -t escapes ":" inside a field as "\:"
    function fields(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; continue; }
            if (c === ":") { out.push(cur); cur = ""; continue; }
            cur += c;
        }
        out.push(cur);
        return out;
    }
    function parse(text: string): void {
        const [wifi, conns] = text.split("\n--\n");
        const known = new Set((conns ?? "").split("\n").map(l => fields(l))
            .filter(f => f.length >= 2 && f[1] === "802-11-wireless").map(f => f[0]));
        const best = {};
        for (const line of (wifi ?? "").split("\n")) {
            const f = fields(line);
            if (f.length < 4 || f[1] === "") continue;
            const n = { ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--",
                        active: f[0] === "*", known: known.has(f[1]) };
            const old = best[n.ssid];
            if (!old || n.active || (!old.active && n.signal > old.signal)) best[n.ssid] = n;
        }
        const list = Object.values(best);
        list.sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
        const was = networks[sel]?.ssid;
        networks = list;
        const i = list.findIndex(n => n.ssid === was);
        sel = i >= 0 ? i : Math.min(sel, Math.max(0, list.length - 1));
    }
    function refresh(rescan: bool): void {
        if (lister.running) return;
        if (rescan) scanning = true;
        lister.command = ["sh", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan " + (rescan ? "yes" : "no")
            + " 2>/dev/null; printf '\\n--\\n'; nmcli -t -f NAME,TYPE connection show 2>/dev/null"];
        lister.running = true;
    }
    Process {
        id: lister
        stdout: StdioCollector { onStreamFinished: self.parse(text) }
        onExited: self.scanning = false
    }
    Timer { interval: 6000; running: self.shown && !self.busy; repeat: true; onTriggered: self.refresh(false) }
    onOpened: refresh(true)

    // ---- joining and leaving
    function act(n: var): void {
        if (!n || busy) return;
        if (n.active) { run(["nmcli", "connection", "down", "id", n.ssid], "LEAVING " + n.ssid); return; }
        if (n.known) { run(["nmcli", "connection", "up", "id", n.ssid], "JOINING " + n.ssid); return; }
        if (!n.secure) { run(["nmcli", "device", "wifi", "connect", n.ssid], "JOINING " + n.ssid); return; }
        asking = n.ssid;
        key.text = "";
        key.forceActiveFocus();
    }
    function join(): void {
        if (asking === "" || key.text === "") return;
        const ssid = asking;
        asking = "";
        run(["nmcli", "device", "wifi", "connect", ssid, "password", key.text], "JOINING " + ssid);
        key.text = "";
        self.forceActiveFocus();
    }
    function run(cmd: var, what: string): void {
        busy = true;
        status = what.toUpperCase() + "…";
        doer.command = cmd;
        doer.running = true;
    }
    Process {
        id: doer
        stdout: StdioCollector {}
        stderr: StdioCollector { id: doerErr }
        onExited: (code, st) => {
            self.busy = false;
            self.status = code === 0 ? "DONE"
                : /secrets|password|802-1x/i.test(doerErr.text) ? "WRONG KEY"
                : "COULD NOT JOIN";
            clearStatus.restart();
            self.refresh(false);
        }
    }
    Timer { id: clearStatus; interval: 4000; onTriggered: self.status = "" }

    // ---- keys
    escapeHandler: () => {
        if (asking !== "") { asking = ""; self.forceActiveFocus(); return true; }
        Widgets.open("controls");                // back to the deck
        return true;
    }
    Keys.onPressed: e => {
        switch (e.key) {
        case Qt.Key_Up: case Qt.Key_K: sel = Math.max(0, sel - 1); break;
        case Qt.Key_Down: case Qt.Key_J: sel = Math.min(networks.length - 1, sel + 1); break;
        case Qt.Key_Return: case Qt.Key_Enter: act(networks[sel]); break;
        case Qt.Key_S: refresh(true); break;
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
            style: Text.Raised; styleColor: Qt.rgba(0.16, 0.17, 0.16, 0.07)   // the faint shadow of e-ink
        }

        // header: /// WI-FI      SCAN
        Row {
            y: 0; spacing: 16
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    y: 8; width: 9; height: 24; color: self.ink
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.5, 0, 12, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
            Item { width: 10; height: 1 }
            Ink { text: "WI-FI"; font.pixelSize: 44 }
        }
        Item {
            anchors.right: parent.right; y: 2; width: scanText.width + 20; height: 38
            Rectangle { anchors.fill: parent; color: self.ink; opacity: scanArea.containsMouse || self.scanning ? 1 : 0 }
            Ink {
                id: scanText
                anchors.centerIn: parent
                text: self.scanning ? "SCANNING" : "SCAN"
                color: scanArea.containsMouse || self.scanning ? self.glass : self.ink
            }
            MouseArea { id: scanArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: self.refresh(true) }
        }
        Rectangle { y: 50; width: parent.width; height: 2.5; color: self.ink }

        // what is going on
        Ink {
            y: 58; width: parent.width; elide: Text.ElideRight
            font.pixelSize: 30
            text: !Net.wifiOn ? "WI-FI IS OFF"
                : self.status !== "" ? self.status
                : Net.wired ? "ON A CABLE"
                : Net.ssid !== "" ? "JOINED: " + Net.ssid.toUpperCase()
                : "NOT JOINED"
        }

        // ---- off: a line to turn it on
        Item {
            visible: !Net.wifiOn
            y: 120; width: parent.width; height: 46
            Rectangle { anchors.fill: parent; color: self.ink; opacity: onArea.containsMouse ? 1 : 0 }
            Ink { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "TURN WI-FI ON"; color: onArea.containsMouse ? self.glass : self.ink }
            MouseArea { id: onArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Net.setWifi(true) }
        }

        // ---- the networks
        ListView {
            id: list
            visible: Net.wifiOn && self.asking === ""
            y: 104; width: parent.width; height: parent.height - 104 - 44
            clip: true
            model: self.networks
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
                // the signal: four bars, as many dark as it is strong
                Row {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 6; height: 8 + index * 5
                            color: line.lit ? self.glass : self.ink
                            opacity: line.modelData.signal >= [1, 30, 55, 75][index] ? 1 : 0.22
                        }
                    }
                }
                Ink {
                    x: 52; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 52 - 120; elide: Text.ElideRight
                    text: line.modelData.ssid
                    color: line.lit ? self.glass : self.ink
                }
                // a lock for a network with a key
                Item {
                    visible: line.modelData.secure
                    x: parent.width - 116; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 22
                    Rectangle { y: 0; x: 3; width: 12; height: 12; radius: 6; color: "transparent"; border.width: 2.5; border.color: line.lit ? self.glass : self.ink }
                    Rectangle { y: 8; width: 18; height: 14; color: line.lit ? self.glass : self.ink }
                }
                Ink {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 28
                    text: line.modelData.active ? "ON" : line.modelData.known ? "SAVED" : ""
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
                visible: self.networks.length === 0
                y: 10; x: 10; font.pixelSize: 30
                text: self.scanning ? "LOOKING…" : "NO NETWORKS IN REACH"
            }
        }

        // ---- a key for a locked network
        Item {
            visible: self.asking !== ""
            y: 112; width: parent.width; height: 200
            Ink { text: "KEY FOR"; font.pixelSize: 30 }
            Ink { y: 34; width: parent.width; elide: Text.ElideRight; text: self.asking.toUpperCase(); font.pixelSize: 40 }
            Rectangle { y: 88; width: parent.width; height: 56; color: "transparent"; border.width: 2.5; border.color: self.ink }
            // a dot for each key, the cursor after them
            Row {
                x: 18; y: 104; spacing: 10
                Repeater {
                    model: Math.min(key.text.length, 24)
                    Rectangle { width: 14; height: 14; radius: 7; color: self.ink }
                }
                Rectangle { width: 3; height: 26; y: -6; color: self.ink; visible: key.activeFocus }
            }
            TextInput {
                id: key
                width: 1; height: 1; opacity: 0
                echoMode: TextInput.Password
                onAccepted: self.join()
                Keys.onEscapePressed: { self.asking = ""; self.forceActiveFocus(); }
            }
            Ink { y: 158; font.pixelSize: 26; text: "ENTER TO JOIN · ESC TO STOP" }
        }

        // foot: how to use it
        Rectangle { y: parent.height - 38; width: parent.width; height: 2.5; color: self.ink }
        Ink {
            y: parent.height - 32; font.pixelSize: 26
            text: "ENTER JOIN · S SCAN · ESC BACK"
        }
    }
}
