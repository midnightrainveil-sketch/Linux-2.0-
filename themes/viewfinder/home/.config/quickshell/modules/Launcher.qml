import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// The launcher (Super + Space, or the aperture on the bottom bar): type a
// few letters, Return opens the one marked. Nothing that matches: the
// words are looked up on the web.
Sheet {
    id: sheet
    name: "launcher"
    title: "Launcher"
    panelWidth: 760

    property string query: ""
    property int selected: 0
    readonly property var results: Apps.search(query)
    readonly property int rows: 8
    readonly property int first: Math.max(0, Math.min(selected - 3, results.length - rows))
    onResultsChanged: selected = 0

    onOpened: { input.text = ""; query = ""; selected = 0; input.forceActiveFocus(); }

    function move(by) { if (results.length) selected = Math.max(0, Math.min(results.length - 1, selected + by)); }
    function launch() {
        const app = results[selected];
        if (app) Apps.launch(app);
        else if (query.trim() !== "")
            Quickshell.execDetached(["xdg-open", Settings.search.replace("%s", encodeURIComponent(query.trim()))]);
        else return;
        Panels.close();
    }

    Column {
        width: sheet.panelWidth

        Item {
            width: parent.width
            height: 58
            Icon { x: 22; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 22 }
            Label {
                x: 60
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "Search"
                color: Theme.faint
                font.pixelSize: 18
            }
            TextInput {
                id: input
                x: 60
                width: parent.width - 80
                anchors.verticalCenter: parent.verticalCenter
                focus: true
                color: Theme.ink
                selectionColor: Theme.ink
                selectedTextColor: "#0b0a0b"
                font.family: Theme.mono
                font.pixelSize: 18
                font.letterSpacing: 1
                clip: true
                onTextChanged: sheet.query = text
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) Panels.close();
                    else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) sheet.move(1);
                    else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) sheet.move(-1);
                    else if (e.key === Qt.Key_PageDown) sheet.move(sheet.rows);
                    else if (e.key === Qt.Key_PageUp) sheet.move(-sheet.rows);
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sheet.launch();
                    else return;
                    e.accepted = true;
                }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 1; width: parent.width - 2; height: 1; color: Theme.ink; opacity: 0.85 }
        }

        Item { width: 1; height: 8 }
        Repeater {
            model: Math.min(sheet.rows, sheet.results.length)
            Item {
                id: row
                required property int index
                readonly property int at: sheet.first + index
                readonly property var app: sheet.results[at] ?? null
                readonly property bool on: sheet.selected === at
                width: sheet.panelWidth
                height: 40
                Rectangle { x: 10; width: parent.width - 20; height: parent.height; color: Theme.ink; opacity: row.on ? 0.82 : 0 }
                Label {
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.at + 1).padStart(2, "0")
                    color: row.on ? "#0b0a0b" : Theme.dim
                    font.pixelSize: 14
                }
                Label {
                    x: 72
                    width: 270
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.app?.name ?? ""
                    color: row.on ? "#0b0a0b" : Theme.ink
                    font.pixelSize: 16
                }
                Label {
                    x: 356
                    width: parent.width - 356 - 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.app?.comment || row.app?.genericName || ""
                    color: row.on ? "#0b0a0b" : Theme.dim
                    font.pixelSize: 13
                    caps: false
                    tracking: 0.4
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: sheet.selected = row.at
                    onClicked: { sheet.selected = row.at; sheet.launch(); }
                }
            }
        }
        Label {
            visible: sheet.results.length === 0
            x: 26
            height: 40
            verticalAlignment: Text.AlignVCenter
            text: sheet.query.trim() === "" ? "No programs found" : "Return: look it up on the web"
            color: Theme.dim
            font.pixelSize: 14
        }
        Item { width: 1; height: 8 }

        Item {
            width: parent.width
            height: 38
            Rectangle { x: 1; width: parent.width - 2; height: 1; color: Theme.ink; opacity: 0.85 }
            Label { x: 26; anchors.verticalCenter: parent.verticalCenter; text: sheet.results.length + " results"; font.pixelSize: 13; color: Theme.dim }
            Label { anchors.right: parent.right; anchors.rightMargin: 26; anchors.verticalCenter: parent.verticalCenter; text: "Return  open     Esc  close"; font.pixelSize: 13; color: Theme.dim }
        }
    }
}
