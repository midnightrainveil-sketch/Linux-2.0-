import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Clippings (Super + V): what was copied, the newest first, pictures too
// (archive-clips, over cliphist). Type to find one.
//
//   click, Return          paste it into the window you were in
//   right-click,
//   Shift + Return         onto the clipboard only
//   Delete                 strike it out of the history
BarPopup {
    id: popup
    name: "clippings"
    side: "middle"
    exclusiveKeys: true

    property var clips: []
    property bool listed: false
    readonly property var found: {
        const q = find.text.trim().toLowerCase();
        if (q === "") return clips;
        return clips.filter(c => c.kind === "text" ? c.text.toLowerCase().indexOf(q) >= 0 : "picture image".indexOf(q) >= 0);
    }
    property int selected: 0
    onFoundChanged: selected = Math.min(selected, Math.max(0, found.length - 1))

    onOpened: {
        find.clear();
        selected = 0;
        lister.running = true;
        find.take();
    }

    Process {
        id: lister
        command: ["archive-clips", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 3) continue;
                    if (f[1] === "image") out.push({ id: f[0], kind: "image", file: f[2], size: f[3] ?? "" });
                    else out.push({ id: f[0], kind: "text", text: f.slice(2).join("\t") });
                }
                popup.clips = out;
                popup.listed = true;
            }
        }
    }

    function run(args: var): void { Quickshell.execDetached(["archive-clips"].concat(args)); }
    function paste(i: int): void {
        const c = found[i];
        if (!c) return;
        Panels.close();
        run(["paste", c.id]);
    }
    function copy(i: int): void {
        const c = found[i];
        if (!c) return;
        Panels.close();
        run(["copy", c.id]);
    }
    function strike(i: int): void {
        const c = found[i];
        if (!c) return;
        run(["delete", c.id]);
        clips = clips.filter(x => x.id !== c.id);
    }
    function wipe(): void {
        run(["wipe"]);
        clips = [];
    }

    IndexCard {
        id: card
        width: 660
        title: "Clippings"
        subtitle: popup.clips.length === 0 ? "Nothing copied yet." : "Of things copied."
        number: String(popup.found.length).padStart(3, "0")
        seed: 1212
        lift: 1.5

        SearchLine {
            id: find
            x: Theme.headerPadH
            width: card.width - 2 * Theme.headerPadH
            onKey: e => {
                const n = popup.found.length;
                if (e.key === Qt.Key_Escape) { Panels.close(); e.accepted = true; }
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { if (n) popup.selected = (popup.selected + 1) % n; e.accepted = true; }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { if (n) popup.selected = (popup.selected + n - 1) % n; e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (e.modifiers & Qt.ShiftModifier) popup.copy(popup.selected); else popup.paste(popup.selected);
                    e.accepted = true;
                }
                else if (e.key === Qt.Key_Delete) { popup.strike(popup.selected); e.accepted = true; }
            }
        }
        Rule { width: card.width; height: implicitHeight; seed: 1213 }

        ListView {
            id: list
            visible: popup.found.length > 0
            width: card.width
            height: Math.min(contentHeight, 470)
            clip: true
            model: popup.found
            currentIndex: popup.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: popup.selected === index
                readonly property bool picture: modelData.kind === "image"
                width: list.width
                height: picture ? 92 : Theme.rowHeight + 6

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4; anchors.rightMargin: 4
                    color: Theme.paperRaised
                    opacity: row.current || mouse.containsMouse ? 1 : 0
                }
                Rectangle { visible: row.current; x: 4; width: 2; height: parent.height; color: Theme.accent }

                InkText {
                    x: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.index + 1).padStart(2, "0")
                    color: Theme.faded
                    font.pixelSize: Theme.sizeLabel
                }
                InkText {
                    visible: !row.picture
                    x: Theme.headerPadH + 40
                    width: parent.width - x - Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.picture ? "" : row.modelData.text
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: Theme.graphite
                }
                // a picture: mounted small, its size typed beside it
                Row {
                    visible: row.picture
                    x: Theme.headerPadH + 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Rectangle {
                        width: shot.paintedWidth + 8
                        height: 76
                        color: Theme.paperCard
                        border.width: 1
                        border.color: Theme.ruleFaint
                        Image {
                            id: shot
                            anchors.centerIn: parent
                            width: 200; height: 68
                            fillMode: Image.PreserveAspectFit
                            source: row.picture ? "file://" + row.modelData.file : ""
                            sourceSize.height: 136
                            asynchronous: true
                            cache: false
                        }
                    }
                    InkText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Picture" + (row.modelData.size ? ",  " + row.modelData.size.replace("x", " × ") : "")
                        color: Theme.faded
                        font.pixelSize: Theme.sizeLabel
                    }
                }
                Rule {
                    visible: row.index < popup.found.length - 1
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom
                    height: implicitHeight
                    weight: 1
                    color: Theme.ruleFaint
                    seed: 1230 + row.index
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: popup.selected = row.index
                    onClicked: m => {
                        if (m.button === Qt.RightButton) popup.copy(row.index);
                        else if (m.button === Qt.MiddleButton) popup.strike(row.index);
                        else popup.paste(row.index);
                    }
                }
            }
        }

        // nothing (yet, or nothing like what was typed)
        Item {
            visible: popup.found.length === 0
            width: card.width
            height: Theme.rowHeight + 6
            InkText {
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: !popup.listed ? "Looking." : popup.clips.length === 0 ? "Copy something, and it is kept here." : "Nothing like that."
                color: Theme.faded
            }
        }

        Rule { width: card.width; height: implicitHeight; seed: 1214 }
        Item {
            width: card.width
            height: 48
            InkText {
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - clearAll.width - 2 * Theme.headerPadH
                text: "Click: paste.  Right: copy.  Del: strike out."
                elide: Text.ElideRight
                color: Theme.faded
                font.pixelSize: Theme.sizeLabel
            }
            ArchiveButton {
                id: clearAll
                anchors.right: parent.right
                anchors.rightMargin: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear all"
                available: popup.clips.length > 0
                onClicked: if (available) popup.wipe()
            }
        }
    }
}
