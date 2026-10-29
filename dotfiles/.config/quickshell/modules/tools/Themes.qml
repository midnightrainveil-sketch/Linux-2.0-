import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Themes (the launcher's "Themes", Instruments → Themes): the desktop
// themes kept (~/.local/share/archive/themes, archive-theme), each with its
// pictures mounted to look through; choose the one to log in to. A new
// choice comes at the next log-in: it changes all of the desktop, and a
// session keeps to the one it began with. Every theme has its own Themes,
// in its own style; this is the Archive's.
//
//   ↑ ↓            the themes        ← →    its pictures
//   Return         use the one marked        Escape   close
BarPopup {
    id: popup
    name: "themes"
    side: "middle"
    exclusiveKeys: true

    property var themes: []
    property string chosen: "archive"
    // (this Themes is the Archive's own: the Archive is the one in use)
    readonly property string current: "archive"
    property bool read_: false
    property int selected: 0
    property int picture: 0
    readonly property var theme: themes[selected] ?? null
    readonly property var pictures: theme?.previews ?? []
    onSelectedChanged: picture = 0

    onOpened: {
        reader.running = true;
        keys.forceActiveFocus();
    }

    // the list, then the one chosen
    Process {
        id: reader
        command: ["sh", "-c", "archive-theme list; archive-theme chosen"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                try { popup.themes = JSON.parse(lines[0] || "[]"); } catch (e) { popup.themes = []; }
                popup.chosen = (lines[1] ?? "archive").trim() || "archive";
                const at = popup.themes.findIndex(t => t.id === popup.chosen);
                popup.selected = Math.max(0, at);
                popup.read_ = true;
            }
        }
    }

    function use(): void {
        if (!theme) return;
        Quickshell.execDetached(["archive-theme", "set", theme.id]);
        chosen = theme.id;
    }
    function step(by: int): void {
        if (themes.length) selected = (selected + by + themes.length) % themes.length;
    }
    function turn(by: int): void {
        if (pictures.length) picture = (picture + by + pictures.length) % pictures.length;
    }
    function standing(t: var): string {
        if (!t) return "";
        if (t.id === current && t.id === chosen) return "In use.";
        if (t.id === chosen) return "From the next log-in.";
        if (t.id === current) return "In use until you log out.";
        return "";
    }

    IndexCard {
        id: card
        width: 1180
        title: "Themes"
        subtitle: "Of other desks to work at."
        number: String(popup.themes.length).padStart(3, "0")
        seed: 1818
        lift: 1.5

        Item {
            id: keys
            width: card.width
            height: 600
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) Panels.close();
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) popup.step(1);
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) popup.step(-1);
                else if (e.key === Qt.Key_Right) popup.turn(1);
                else if (e.key === Qt.Key_Left) popup.turn(-1);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) popup.use();
                else return;
                e.accepted = true;
            }

            // ------------------------------------------------ the themes kept
            Column {
                id: list
                x: 0
                y: 14
                width: 340
                Repeater {
                    model: popup.themes
                    Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool on: popup.selected === index
                        width: list.width
                        height: 82
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            color: Theme.paperRaised
                            opacity: row.on || rowMouse.containsMouse ? 1 : 0
                        }
                        Rectangle { visible: row.on; x: 4; width: 2; height: parent.height; color: Theme.accent }
                        Column {
                            x: Theme.headerPadH
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 14
                            spacing: 3
                            InkText {
                                text: row.modelData.name ?? row.modelData.id
                                color: Theme.graphite
                                font.pixelSize: Theme.sizeTitle
                                caps: true
                                tracking: 0.08
                            }
                            InkText {
                                text: row.modelData.by ?? ""
                                color: Theme.faded
                                font.pixelSize: Theme.sizeSmall
                            }
                            InkText {
                                visible: text !== ""
                                text: popup.standing(row.modelData)
                                color: row.modelData.id === popup.chosen && row.modelData.id !== popup.current ? Theme.accent : Theme.madder
                                font.pixelSize: Theme.sizeSmall
                                font.italic: true
                            }
                        }
                        Rule {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: 6; anchors.rightMargin: 6
                            anchors.bottom: parent.bottom
                            height: implicitHeight
                            weight: 1
                            color: Theme.ruleFaint
                            seed: 1830 + row.index
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.selected = row.index
                            onDoubleClicked: { popup.selected = row.index; popup.use(); }
                        }
                    }
                }
                InkText {
                    x: Theme.headerPadH
                    width: list.width - x - 14
                    topPadding: 14
                    wrapMode: Text.WordWrap
                    text: !popup.read_ ? "Looking." : "Further themes are filed here as they arrive."
                    color: Theme.faded
                    font.pixelSize: Theme.sizeSmall
                    font.italic: true
                }
            }

            Rule {
                vertical: true
                x: list.width + 8
                y: 0
                height: keys.height
                width: implicitWidth
                seed: 1819
            }

            // ------------------------------------------------ its pictures
            Item {
                id: plate
                x: list.width + 38
                y: 22
                width: 760
                height: 475

                // the photograph, mounted on card with a white margin
                Rectangle {
                    anchors.fill: parent
                    color: Theme.paperCard
                    border.width: 1
                    border.color: Theme.ruleFaint
                    Image {
                        id: shot
                        anchors.fill: parent
                        anchors.margins: 10
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 1480
                        source: popup.theme && popup.pictures.length
                            ? "file://" + popup.theme.dir + "/" + popup.pictures[popup.picture] : ""
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }
                    InkText {
                        anchors.centerIn: parent
                        visible: shot.status !== Image.Ready
                        text: popup.pictures.length ? "Developing." : "No pictures of this one."
                        color: Theme.faded
                    }
                }
                Tape { x: -14; y: -8; width: 86; rotation: -32; seed: 1841 }
                Tape { x: parent.width - 72; y: -8; width: 86; rotation: 30; seed: 1842 }

                // the other pictures: click either half
                MouseArea {
                    width: parent.width / 2; height: parent.height
                    enabled: popup.pictures.length > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: popup.turn(-1)
                }
                MouseArea {
                    x: parent.width / 2
                    width: parent.width / 2; height: parent.height
                    enabled: popup.pictures.length > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: popup.turn(1)
                }
            }

            // its caption, and which of its pictures this is
            InkText {
                x: plate.x
                y: plate.y + plate.height + 14
                text: (popup.theme?.captions ?? [])[popup.picture] ?? ""
                color: Theme.soft
                font.pixelSize: Theme.sizeSmall
                font.italic: true
            }
            Row {
                anchors.right: plate.right
                y: plate.y + plate.height + 12
                spacing: 14
                visible: popup.pictures.length > 1
                InkText {
                    text: "‹"
                    color: Theme.faded
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: popup.turn(-1) }
                }
                InkText {
                    text: "Pl. " + (popup.picture + 1) + " of " + popup.pictures.length
                    color: Theme.faded
                    font.pixelSize: Theme.sizeSmall
                }
                InkText {
                    text: "›"
                    color: Theme.faded
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: popup.turn(1) }
                }
            }
            InkText {
                x: plate.x
                y: plate.y + plate.height + 40
                width: plate.width
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: popup.theme?.summary ?? ""
                color: Theme.soft
                font.pixelSize: Theme.sizeSmall
            }
        }

        Rule { width: card.width; height: implicitHeight; seed: 1820 }

        // ------------------------------------------------ choosing
        Item {
            width: card.width
            height: 56
            readonly property bool isChosen: popup.theme !== null && popup.theme.id === popup.chosen
            readonly property bool isCurrent: popup.theme !== null && popup.theme.id === popup.current
            InkText {
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: popup.theme === null ? ""
                    : parent.isChosen && parent.isCurrent ? "The desk you are at."
                    : parent.isChosen ? "Chosen. It is laid out when you next log in."
                    : "A theme changes the whole desktop; your files and programs stay as they are."
                color: Theme.faded
                font.pixelSize: Theme.sizeLabel
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                ArchiveButton {
                    visible: popup.theme !== null && !parent.parent.isChosen
                    primary: true
                    text: parent.parent.isCurrent ? "Keep this one" : "Use this theme"
                    onClicked: popup.use()
                }
                ArchiveButton {
                    visible: parent.parent.isChosen && !parent.parent.isCurrent
                    primary: true
                    text: "Log out now"
                    onClicked: { Panels.close(); Quickshell.execDetached(["archive-session", "logout"]); }
                }
            }
        }
    }
}
