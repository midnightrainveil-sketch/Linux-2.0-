import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Themes (in the launcher: "Themes"): the desktop themes kept, with a
// picture of each. Return chooses the one marked; it comes at the next
// log-in.
Sheet {
    id: sheet
    name: "themes"
    title: "Themes"
    panelWidth: 1040

    property var themes: []
    property string chosen: ""
    property int selected: 0
    readonly property var theme: themes[selected] ?? null

    onOpened: { reader.running = true; keys.forceActiveFocus(); }

    Process {
        id: reader
        command: ["sh", "-c", "ultra-theme list; ultra-theme chosen"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                try { sheet.themes = JSON.parse(lines[0] || "[]"); } catch (e) { sheet.themes = []; }
                sheet.chosen = (lines[1] ?? "").trim();
                sheet.selected = Math.max(0, sheet.themes.findIndex(t => t.id === sheet.chosen));
            }
        }
    }
    function use() {
        if (!theme) return;
        Quickshell.execDetached(["ultra-theme", "set", theme.id]);
        chosen = theme.id;
    }

    Item {
        id: keys
        width: sheet.panelWidth
        height: 470
        focus: true
        Keys.onPressed: e => {
            const n = sheet.themes.length;
            if (e.key === Qt.Key_Escape) Panels.close();
            else if ((e.key === Qt.Key_Down || e.key === Qt.Key_Tab) && n) sheet.selected = (sheet.selected + 1) % n;
            else if ((e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) && n) sheet.selected = (sheet.selected + n - 1) % n;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sheet.use();
            else return;
            e.accepted = true;
        }

        Column {
            y: 8
            width: 330
            Repeater {
                model: sheet.themes
                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: sheet.selected === index
                    width: 330
                    height: 54
                    Rectangle { x: 10; width: parent.width - 10; height: parent.height; color: Theme.ink; opacity: row.on ? 0.82 : 0 }
                    Label { x: 26; y: 9; width: parent.width - 36; text: row.modelData.name ?? row.modelData.id; color: row.on ? "#0b0a0b" : Theme.ink; font.pixelSize: 16 }
                    Label {
                        x: 26; y: 31
                        width: parent.width - 36
                        text: row.modelData.id === sheet.chosen ? "From the next log-in" : (row.modelData.by ?? "")
                        color: row.on ? "#0b0a0b" : Theme.dim
                        font.pixelSize: 12
                    }
                    MouseArea { anchors.fill: parent; onClicked: sheet.selected = row.index; onDoubleClicked: sheet.use() }
                }
            }
        }
        Rectangle { x: 350; width: 1; height: parent.height - 38; color: Theme.ink; opacity: 0.85 }
        Image {
            x: 370; y: 18
            width: sheet.panelWidth - 390
            height: 300
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
            source: sheet.theme && (sheet.theme.previews ?? []).length ? "file://" + sheet.theme.dir + "/" + sheet.theme.previews[0] : ""
        }
        Text {
            x: 370; y: 332
            width: sheet.panelWidth - 390
            height: 92
            text: sheet.theme?.summary ?? ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            lineHeight: 1.25
        }
        Item {
            y: parent.height - 38
            width: parent.width
            height: 38
            Rectangle { x: 1; width: parent.width - 2; height: 1; color: Theme.ink; opacity: 0.85 }
            Label { x: 26; anchors.verticalCenter: parent.verticalCenter; text: sheet.themes.length + " themes"; font.pixelSize: 13; color: Theme.dim }
            Label { anchors.right: parent.right; anchors.rightMargin: 26; anchors.verticalCenter: parent.verticalCenter; text: "Return  use from the next log-in     Esc  close"; font.pixelSize: 13; color: Theme.dim }
        }
    }
}
