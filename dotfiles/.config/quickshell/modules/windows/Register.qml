import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// The Register: every open window on one card, the most recently used
// first, put-away (minimised) ones included. Opened from the bar's register
// button, or with Alt+Tab: Tab again steps down the list, letting go of Alt
// goes to the one marked, like any window switcher.
//
//   click, Return            go to the window (a put-away one comes back)
//   right-click, -           put it away, or take it out again
//   middle-click, x          close it
//   arrows, Tab, j / k       step; Escape closes the card
BarPopup {
    id: popup
    name: "register"
    side: "left"
    offset: 60
    exclusiveKeys: true

    property var windows: []
    property int selected: 0
    property bool altMode: false        // opened by Alt+Tab: letting go of Alt picks
    property int pendingSelect: 0

    // ---------------------------------------------------------------- opening
    function openWith(step: int, alt: bool): void {
        altMode = alt;
        pendingSelect = step;
        selected = 0;
        lister.running = true;
        Panels.show("register");
    }
    function toggle(): void {
        if (Panels.open === "register") Panels.close();
        else openWith(0, false);
    }
    // Alt+Tab / Alt+Shift+Tab
    function step(d: int): void {
        if (Panels.open !== "register") { openWith(d > 0 ? 1 : -1, true); return; }
        if (windows.length > 0) selected = (selected + d + windows.length) % windows.length;
    }
    // Alt let go
    function commit(): void {
        if (Panels.open === "register" && altMode) activate(selected);
    }

    onOpened: keys.forceActiveFocus()

    Process {
        id: lister
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let all = [];
                try { all = JSON.parse(text); } catch (e) { all = []; }
                const list = all.filter(w => w.mapped !== false && (w.class || w.title))
                                .sort((a, b) => (a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99));
                popup.windows = list;
                const n = list.length;
                popup.selected = n === 0 ? 0 : ((popup.pendingSelect % n) + n) % n;
            }
        }
    }

    // ---------------------------------------------------------------- what a row is
    function where(w): string {
        const n = w.workspace?.name ?? "";
        if (n === "special:drawer") return "Put away";
        if (n === "special:desk") return "Behind the desk";
        if (n.startsWith("special:")) return n.substring(8);
        return "Desk " + (w.workspace?.id ?? "?");
    }
    function putAway(w): bool { return (w.workspace?.name ?? "") === "special:drawer"; }
    function isDesk(w): bool { return w.class === "archive.desk"; }

    function entryFor(w) {
        const cls = w.class || w.initialClass || "";
        if (!cls) return null;
        return DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(cls) : DesktopEntries.byId(cls);
    }

    function dispatch(lua: string): void {
        Quickshell.execDetached(["hyprctl", "dispatch", lua]);
    }
    function sel(w): string { return "window = \"address:" + w.address + "\""; }

    // ---------------------------------------------------------------- actions
    function activate(i: int): void {
        const w = windows[i];
        Panels.close();
        if (!w) return;
        if (isDesk(w)) { Quickshell.execDetached(["archive-desk"]); return; }
        if (putAway(w))
            dispatch("hl.dsp.window.move({ workspace = \"e+0\", follow = true, " + sel(w) + " })");
        dispatch("hl.dsp.focus({ " + sel(w) + " })");
    }
    function toggleAway(i: int): void {
        const w = windows[i];
        if (!w) return;
        if (putAway(w))
            dispatch("hl.dsp.window.move({ workspace = \"e+0\", follow = true, " + sel(w) + " })");
        else
            dispatch("hl.dsp.window.move({ workspace = \"special:drawer\", follow = false, " + sel(w) + " })");
        refresh.restart();
    }
    function closeWindow(i: int): void {
        const w = windows[i];
        if (!w) return;
        dispatch("hl.dsp.window.close({ " + sel(w) + " })");
        refresh.restart();
    }
    Timer { id: refresh; interval: 250; onTriggered: { popup.pendingSelect = popup.selected; lister.running = true; } }

    // ---------------------------------------------------------------- the card
    IndexCard {
        id: card
        width: 560
        title: "Register"
        subtitle: popup.windows.length === 0 ? "Nothing open." : "Of open documents."
        number: String(popup.windows.length).padStart(3, "0")
        labelWidth: 46
        seed: 808
        lift: 1.5

        Item {
            id: keys
            width: 1; height: 0
            focus: true
            Keys.onPressed: e => {
                const n = popup.windows.length;
                if (e.key === Qt.Key_Escape) { Panels.close(); return; }
                if (n === 0) return;
                if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || e.key === Qt.Key_J) { popup.selected = (popup.selected + 1) % n; e.accepted = true; return; }
                if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || e.key === Qt.Key_K) { popup.selected = (popup.selected + n - 1) % n; e.accepted = true; return; }
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { popup.activate(popup.selected); return; }
                if (e.key === Qt.Key_Minus) { popup.toggleAway(popup.selected); return; }
                if (e.key === Qt.Key_X || e.key === Qt.Key_Delete) { popup.closeWindow(popup.selected); return; }
            }
            Keys.onReleased: e => {
                if (e.key === Qt.Key_Alt && popup.altMode) popup.commit();
            }
        }

        ListView {
            id: list
            visible: popup.windows.length > 0
            width: card.width
            height: Math.min(Math.max(popup.windows.length, 1), 11) * rowH
            readonly property int rowH: Theme.rowHeight + 6
            clip: true
            interactive: popup.windows.length > 11
            model: popup.windows
            currentIndex: popup.selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: popup.selected === index
                readonly property bool away: popup.putAway(modelData)
                readonly property var entry: popup.entryFor(modelData)
                width: list.width
                height: list.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4; anchors.rightMargin: 4
                    color: Theme.paperRaised
                    opacity: row.current || mouse.containsMouse ? 1 : 0
                }
                Rectangle { visible: row.current; x: 4; width: 2; height: parent.height; color: Theme.accent }

                // the application's picture, small and in grey, like the catalogue's
                Item {
                    x: 14
                    width: 22; height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        id: icon
                        anchors.fill: parent
                        sourceSize: Qt.size(44, 44)
                        source: row.entry && row.entry.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
                        visible: false
                        asynchronous: true
                    }
                    Desaturate {
                        anchors.fill: icon
                        source: icon
                        desaturation: 0.85
                        opacity: row.away ? 0.45 : 0.85
                        visible: icon.status === Image.Ready
                    }
                    InkText {
                        anchors.centerIn: parent
                        visible: icon.status !== Image.Ready
                        text: "·"
                        color: Theme.faded
                    }
                }
                Rule {
                    vertical: true
                    x: card.labelWidth
                    anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: implicitWidth
                    seed: 810 + row.index
                }

                InkText {
                    id: titleText
                    anchors.left: parent.left
                    anchors.leftMargin: card.labelWidth + 14
                    anchors.right: whereText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: (row.entry?.name ?? row.modelData.class ?? "") + (row.modelData.title && row.modelData.title !== (row.entry?.name ?? "") ? "  " + row.modelData.title : "")
                    elide: Text.ElideRight
                    color: row.away ? Theme.faded : Theme.graphite
                }
                InkText {
                    id: whereText
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.where(row.modelData)
                    color: row.away ? Theme.madder : Theme.faded
                    font.pixelSize: Theme.sizeLabel
                }
                Rule {
                    visible: row.index < popup.windows.length - 1
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom
                    height: implicitHeight
                    weight: 1
                    color: Theme.ruleFaint
                    seed: 830 + row.index
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: popup.selected = row.index
                    onClicked: m => {
                        if (m.button === Qt.RightButton) popup.toggleAway(row.index);
                        else if (m.button === Qt.MiddleButton) popup.closeWindow(row.index);
                        else popup.activate(row.index);
                    }
                }
            }
        }

        // nothing open
        Item {
            visible: popup.windows.length === 0
            width: card.width
            height: list.rowH
            InkText {
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: "The desk is clear."
                color: Theme.faded
            }
        }

        InkText {
            x: Theme.headerPadH
            width: card.width - 2 * Theme.headerPadH
            topPadding: 8
            bottomPadding: 6
            text: "Click: go to.  Right-click: put away / take out.  Middle-click: close."
            color: Theme.faded
            font.pixelSize: Theme.sizeLabel
            wrapMode: Text.WordWrap
        }
    }
}
