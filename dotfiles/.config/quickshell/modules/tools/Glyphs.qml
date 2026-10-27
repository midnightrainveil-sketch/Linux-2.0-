import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Glyphs (Super + .): emoji, and the marks a keyboard lacks (dashes,
// quotes, arrows, signs), in drawers by kind, the ones used lately first.
// Type to find one by name (assets/emoji: tools/make_emoji.py).
//
//   click, Return          typed into the window you were in
//   right-click,
//   Shift + Return         onto the clipboard instead
//   arrows                 move; Tab, Shift + Tab: the next / last drawer
BarPopup {
    id: popup
    name: "glyphs"
    side: "middle"
    exclusiveKeys: true

    property var groups: []
    property var recent: []
    property int tab: 0                 // 0: used lately, then the groups
    property int selected: 0
    readonly property int columns: 12
    readonly property int maxRecent: 36

    readonly property var shown_: {
        const q = find.text.trim().toLowerCase();
        if (q !== "") {
            const words = q.split(/\s+/);
            const out = [];
            for (const g of groups)
                for (const it of g.items)
                    if (words.every(w => (it[1] + " " + it[2]).toLowerCase().indexOf(w) >= 0)) {
                        out.push(it);
                        if (out.length >= 240) return out;
                    }
            return out;
        }
        if (tab === 0) return recent;
        return groups[tab - 1]?.items ?? [];
    }
    onShown_Changed: selected = 0
    readonly property var current: shown_[selected] ?? null

    onOpened: {
        find.clear();
        tab = recent.length > 0 ? 0 : 1;
        selected = 0;
        find.take();
    }

    FileView {
        path: Qt.resolvedUrl("../../assets/emoji/emoji.json").toString().replace("file://", "")
        printErrors: false
        onLoaded: { try { popup.groups = JSON.parse(text()).groups; } catch (e) {} }
    }
    // the ones used lately, newest first: [[glyph, name, words], ...]
    FileView {
        id: recentFile
        path: Settings.stateHome + "/archive/glyphs-recent"
        printErrors: false
        onLoaded: { try { popup.recent = JSON.parse(text()); } catch (e) {} }
    }
    function remember(it: var): void {
        recent = [it].concat(recent.filter(r => r[0] !== it[0])).slice(0, maxRecent);
        recentFile.setText(JSON.stringify(recent));
    }

    function use(i: int, copyOnly: bool): void {
        const it = shown_[i];
        if (!it) return;
        remember(it);
        Panels.close();
        if (copyOnly) Quickshell.execDetached(["wl-copy", "--", it[0]]);
        else Quickshell.execDetached(["archive-clips", "type", it[0]]);
    }
    function move(by: int): void {
        const n = shown_.length;
        if (n > 0) selected = Math.max(0, Math.min(n - 1, selected + by));
    }
    function turn(by: int): void {
        const n = groups.length + 1;
        tab = (tab + by + n) % n;
        if (tab === 0 && recent.length === 0) tab = (tab + by + n) % n;
    }
    // emoji drawn in colour; the marks typed, like the rest of the archive
    function marks(it: var): bool { return it !== null && it[0].length <= 2 && it[0].codePointAt(0) < 0x2600; }

    IndexCard {
        id: card
        width: popup.columns * 48 + 2 * Theme.headerPadH
        title: "Glyphs"
        subtitle: find.text.trim() !== "" ? "Found." : popup.tab === 0 ? "Used lately." : (popup.groups[popup.tab - 1]?.name ?? "") + "."
        number: String(popup.shown_.length).padStart(3, "0")
        seed: 1616
        lift: 1.5

        SearchLine {
            id: find
            x: Theme.headerPadH
            width: card.width - 2 * Theme.headerPadH
            onKey: e => {
                const shift = e.modifiers & Qt.ShiftModifier;
                if (e.key === Qt.Key_Escape) { Panels.close(); e.accepted = true; }
                else if (e.key === Qt.Key_Right) { popup.move(1); e.accepted = true; }
                else if (e.key === Qt.Key_Left) { popup.move(-1); e.accepted = true; }
                else if (e.key === Qt.Key_Down) { popup.move(popup.columns); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { popup.move(-popup.columns); e.accepted = true; }
                else if (e.key === Qt.Key_Tab) { find.clear(); popup.turn(1); e.accepted = true; }
                else if (e.key === Qt.Key_Backtab) { find.clear(); popup.turn(-1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { popup.use(popup.selected, shift); e.accepted = true; }
            }
        }
        Rule { width: card.width; height: implicitHeight; seed: 1617 }

        // the drawers: used lately, then each kind
        Row {
            x: Theme.headerPadH - 6
            height: 42
            Repeater {
                model: [{ name: "Used lately", tab: "🕘" }].concat(popup.groups)
                Item {
                    id: drawer
                    required property var modelData
                    required property int index
                    readonly property bool on: popup.tab === index && find.text.trim() === ""
                    readonly property bool empty: index === 0 && popup.recent.length === 0
                    width: 48
                    height: 42
                    opacity: empty ? 0.3 : 1
                    Text {
                        anchors.centerIn: parent
                        text: drawer.modelData.tab
                        font.family: drawer.modelData.name === "Marks" ? Theme.typewriter : "Noto Color Emoji"
                        font.pixelSize: 20
                        color: Theme.soft
                        opacity: drawer.on || tabMouse.containsMouse ? 1 : 0.55
                    }
                    Rectangle {
                        visible: drawer.on
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 24; height: 2
                        color: Theme.accent
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drawer.empty ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!drawer.empty) { find.clear(); popup.tab = drawer.index; find.take(); }
                    }
                }
            }
        }
        Rule { width: card.width; height: implicitHeight; color: Theme.ruleFaint; weight: 1; seed: 1618 }

        GridView {
            id: grid
            x: Theme.headerPadH
            width: popup.columns * 48
            height: 6 * 48 + 8
            topMargin: 4
            cellWidth: 48
            cellHeight: 48
            clip: true
            model: popup.shown_
            currentIndex: popup.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool current: popup.selected === index
                width: 48
                height: 48
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: Theme.paperRaised
                    border.width: cell.current ? 1 : 0
                    border.color: Theme.accent
                    opacity: cell.current || cellMouse.containsMouse ? 1 : 0
                }
                Text {
                    anchors.centerIn: parent
                    text: cell.modelData[0]
                    font.family: popup.marks(cell.modelData) ? Theme.typewriter : "Noto Color Emoji"
                    font.pixelSize: popup.marks(cell.modelData) ? 24 : 26
                    color: Theme.graphite
                }
                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: popup.selected = cell.index
                    onClicked: m => popup.use(cell.index, m.button === Qt.RightButton)
                }
            }

            InkText {
                visible: popup.shown_.length === 0
                y: 10
                text: find.text.trim() !== "" ? "Nothing by that name." : "None used yet."
                color: Theme.faded
            }
        }

        Rule { width: card.width; height: implicitHeight; seed: 1619 }
        // the marked one's name
        Item {
            width: card.width
            height: 46
            InkText {
                x: Theme.headerPadH
                width: parent.width - 2 * Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: popup.current ? popup.current[1].charAt(0).toUpperCase() + popup.current[1].slice(1) + "." : "Click: type it.  Right-click: copy it."
                color: popup.current ? Theme.soft : Theme.faded
                font.pixelSize: Theme.sizeLabel
                elide: Text.ElideRight
            }
        }
    }
}
