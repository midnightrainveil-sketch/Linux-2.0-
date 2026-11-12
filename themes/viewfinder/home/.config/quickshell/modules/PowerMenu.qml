import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// The power menu (Super + Shift + Escape, the power key, or the bar's
// power mark). The letter, or the arrows and Return. Reboot and shut down
// ask once more.
Sheet {
    id: sheet
    name: "power"
    title: "Power"
    panelWidth: 460

    readonly property var actions: [
        { key: "l", word: "Lock",      cmd: ["qs", "ipc", "call", "lock", "lock"], confirm: false },
        { key: "s", word: "Suspend",   cmd: ["systemctl", "suspend"],             confirm: false },
        { key: "o", word: "Log out",   cmd: ["ultra-session", "logout"],          confirm: true },
        { key: "r", word: "Reboot",    cmd: ["systemctl", "reboot"],              confirm: true },
        { key: "d", word: "Shut down", cmd: ["systemctl", "poweroff"],            confirm: true }
    ]
    property int selected: 0
    property int asked: -1

    onOpened: { selected = 0; asked = -1; keys.forceActiveFocus(); }

    function run(i) {
        const a = actions[i];
        if (!a) return;
        selected = i;
        if (a.confirm && asked !== i) { asked = i; return; }
        Panels.close();
        Quickshell.execDetached(a.cmd);
    }

    Column {
        id: keys
        width: sheet.panelWidth
        focus: true
        topPadding: 8
        bottomPadding: 8
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { if (sheet.asked >= 0) sheet.asked = -1; else Panels.close(); }
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { sheet.selected = (sheet.selected + 1) % sheet.actions.length; sheet.asked = -1; }
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { sheet.selected = (sheet.selected + sheet.actions.length - 1) % sheet.actions.length; sheet.asked = -1; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sheet.run(sheet.selected);
            else {
                const i = sheet.actions.findIndex(a => a.key === e.text.toLowerCase());
                if (i < 0) return;
                sheet.run(i);
            }
            e.accepted = true;
        }
        Repeater {
            model: sheet.actions
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool on: sheet.selected === index
                width: sheet.panelWidth
                height: 44
                Rectangle { x: 10; width: parent.width - 20; height: parent.height; color: Theme.ink; opacity: row.on ? 0.82 : 0 }
                Label { x: 26; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.key; color: row.on ? "#0b0a0b" : Theme.dim; font.pixelSize: 14 }
                Label {
                    x: 72
                    anchors.verticalCenter: parent.verticalCenter
                    text: sheet.asked === row.index ? row.modelData.word + "?  Return again" : row.modelData.word
                    color: row.on ? "#0b0a0b" : Theme.ink
                    font.pixelSize: 16
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: if (sheet.selected !== row.index) { sheet.selected = row.index; sheet.asked = -1; }
                    onClicked: sheet.run(row.index)
                }
            }
        }
    }
}
