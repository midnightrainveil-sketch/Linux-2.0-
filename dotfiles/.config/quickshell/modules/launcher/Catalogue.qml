import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Card Catalogue (launcher): centre, 560 px. Header CATALOGUE with the
// result count as No.; a typed "Query: _" field; results numbered 01, 02...
// with their category in ink.faded.
BarPopup {
    id: popup
    name: "catalogue"
    side: "middle"
    exclusiveKeys: true

    property string query: ""
    property int selected: 0
    readonly property int maxRows: 9

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        if (q === "") return apps.slice().sort((a, b) => a.name.localeCompare(b.name)).slice(0, maxRows);
        const scored = [];
        for (const a of apps) {
            const name = a.name.toLowerCase();
            const extra = [a.genericName ?? "", (a.keywords ?? []).join(" "), (a.categories ?? []).join(" "), a.id ?? ""].join(" ").toLowerCase();
            let s = 0;
            if (name.startsWith(q)) s = 100;
            else if (name.split(/\s+/).some(w => w.startsWith(q))) s = 80;
            else if (name.includes(q)) s = 60;
            else if (extra.includes(q)) s = 30;
            if (s > 0) scored.push({ a, s });
        }
        scored.sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name));
        return scored.slice(0, maxRows).map(x => x.a);
    }

    // A short archive word for each application's category.
    function category(app) {
        const c = app.categories ?? [];
        const map = [["WebBrowser", "browser"], ["Network", "correspondence"], ["TerminalEmulator", "terminal"],
                     ["Development", "workshop"], ["Graphics", "plates"], ["AudioVideo", "audio-visual"],
                     ["Audio", "audio"], ["Video", "film"], ["Office", "office"], ["Game", "games"],
                     ["Settings", "instruments"], ["System", "system"], ["Utility", "tools"], ["Education", "study"],
                     ["Science", "science"], ["FileManager", "drawers"]];
        for (const [k, v] of map) if (c.indexOf(k) >= 0) return v;
        return c.length ? c[0].toLowerCase() : "application";
    }

    function launch(app) {
        if (!app) return;
        app.execute();
        Panels.close();
    }

    onOpened: {
        query = "";
        selected = 0;
        input.text = "";
        input.forceActiveFocus();
    }
    onResultsChanged: selected = 0

    IndexCard {
        id: card
        width: 560
        title: "Catalogue"
        subtitle: "Index of applications."
        number: String(popup.results.length).padStart(2, "0")
        seed: 404
        lift: 1.6

        // Query: ______
        Item {
            width: parent.width
            height: 46

            InkText {
                id: queryLabel
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: "Query:"
                color: Theme.faded
                font.pixelSize: Theme.sizeData + 1
            }

            TextInput {
                id: input
                anchors.left: queryLabel.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.typewriter
                font.pixelSize: Theme.sizeData + 1
                color: Theme.graphite
                selectionColor: Theme.paperRaised
                selectedTextColor: Theme.graphite
                cursorVisible: false
                cursorDelegate: Item {}
                clip: true
                onTextChanged: popup.query = text

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { Panels.close(); event.accepted = true; }
                    else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier) || event.key === Qt.Key_Tab) {
                        popup.selected = Math.min(popup.results.length - 1, popup.selected + 1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) || event.key === Qt.Key_Backtab) {
                        popup.selected = Math.max(0, popup.selected - 1); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        popup.launch(popup.results[popup.selected]); event.accepted = true;
                    }
                }

                // block caret in ink.graphite, blinking slowly (1 s)
                Rectangle {
                    x: input.cursorRectangle.x + 1
                    y: input.cursorRectangle.y + 1
                    width: 8
                    height: input.cursorRectangle.height - 2
                    color: Theme.graphite
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: popup.shown
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 500 }
                    }
                }
            }

            // underline only, darkening while in use
            Rule {
                anchors.left: input.left
                anchors.right: input.right
                anchors.top: input.bottom
                anchors.topMargin: 3
                height: implicitHeight
                weight: 1
                color: input.text.length ? Theme.ruleInk : Theme.ruleFaint
                seed: 405
            }
        }

        Rule { width: parent.width; height: implicitHeight; seed: 406 }

        Repeater {
            model: popup.results

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: popup.selected === index

                width: card.width
                height: Theme.rowHeight + 2

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    color: Theme.paperRaised
                    opacity: row.current || rowMouse.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                }
                Rectangle {
                    visible: row.current
                    x: 4
                    width: 2
                    height: parent.height
                    color: Theme.accent
                }

                InkText {
                    id: idx
                    x: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(row.index + 1).padStart(2, "0")
                    color: row.current ? Theme.accent : Theme.faded
                }
                InkText {
                    anchors.left: idx.right
                    anchors.leftMargin: 18
                    anchors.right: cat.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: Theme.graphite
                    font.bold: false
                    elide: Text.ElideRight
                }
                InkText {
                    id: cat
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: popup.category(row.modelData)
                    color: Theme.faded
                    font.pixelSize: Theme.sizeLabel
                }
                Rule {
                    visible: row.index < popup.results.length - 1
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom
                    height: implicitHeight
                    weight: 1
                    color: Theme.ruleFaint
                    seed: 420 + row.index
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: popup.selected = row.index
                    onClicked: popup.launch(row.modelData)
                }
            }
        }

        // nothing found
        Item {
            visible: popup.results.length === 0
            width: parent.width
            height: Theme.rowHeight + 8
            InkText {
                x: Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                text: "No record under that heading."
                color: Theme.faded
            }
        }

        Item { width: 1; height: 6 }
    }
}
