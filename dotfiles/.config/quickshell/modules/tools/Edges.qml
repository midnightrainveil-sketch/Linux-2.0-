import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Paper edges (Instruments -> Edges): the size of the windows' torn edges,
// with a corner of each to look at (assets/edges, from tools/deckle-preview).
// It applies at once (archive-edges).
BarPopup {
    id: popup
    name: "edges"
    side: "right"

    readonly property var sizes: ["1", "1.5", "2", "2.5"]
    property string chosen: "1"
    // the one looked at: the chosen one, or the one under the pointer
    property int looking: -1
    readonly property string shown: looking >= 0 ? sizes[looking] : chosen

    onOpened: { looking = -1; file.reload(); keys.forceActiveFocus(); }

    FileView {
        id: file
        path: Settings.stateHome + "/archive/edges"
        printErrors: false
        onLoaded: {
            const v = String(Number(text().trim()));
            popup.chosen = popup.sizes.indexOf(v) >= 0 ? v : "1";
        }
        onLoadFailed: popup.chosen = "1"
    }

    function pick(i: int): void {
        chosen = sizes[i];
        Quickshell.execDetached(["archive-edges", chosen]);
    }

    IndexCard {
        id: card
        width: 460
        title: "Paper edges"
        subtitle: "Of the windows' torn edges."
        number: ""
        labelWidth: 100
        seed: 2020
        lift: 1.4

        Item {
            id: keys
            width: 1; height: 0
            focus: true
            Keys.onPressed: e => {
                const i = popup.sizes.indexOf(popup.chosen);
                if (e.key === Qt.Key_Escape) Panels.close();
                else if (e.key === Qt.Key_Right) popup.pick(Math.min(popup.sizes.length - 1, i + 1));
                else if (e.key === Qt.Key_Left) popup.pick(Math.max(0, i - 1));
                else return;
                e.accepted = true;
            }
        }

        DataRow {
            label: "Size"
            labelWidth: card.labelWidth
            Toggle {
                id: sizes
                anchors.verticalCenter: parent.verticalCenter
                options: ["1×", "1.5×", "2×", "2.5×"]
                current: popup.sizes.indexOf(popup.chosen)
                onPicked: i => popup.pick(i)
            }
            // which size the pointer is over, to look at it before choosing
            HoverHandler {
                target: sizes
                onPointChanged: {
                    if (!hovered) { popup.looking = -1; return; }
                    let x = point.position.x, i = 0;
                    for (; i < sizes.children.length - 1; ++i) {
                        const c = sizes.children[i];
                        if (x < c.x + c.width + sizes.spacing / 2) break;
                    }
                    popup.looking = Math.min(i, popup.sizes.length - 1);
                }
                onHoveredChanged: if (!hovered) popup.looking = -1
            }
        }

        // a corner of a window at that size, at its real size on the screen
        Item {
            width: card.width
            height: shot.height + 28
            Rectangle {
                id: frame
                x: (parent.width - width) / 2
                y: 14
                width: shot.width + 2
                height: shot.height + 2
                color: "transparent"
                border.width: 1
                border.color: Theme.ruleFaint
                Image {
                    id: shot
                    x: 1; y: 1
                    width: 560 / 1.5
                    height: 330 / 1.5
                    source: Qt.resolvedUrl("../../assets/edges/" + (Theme.night > 0.5 ? "night-" : "day-") + popup.shown + ".jpg")
                    sourceSize: Qt.size(560, 330)
                    smooth: true
                    asynchronous: true
                }
            }
        }

        Rule { width: card.width; height: implicitHeight; seed: 2021 }
        Item {
            width: card.width
            height: 64
            InkText {
                x: Theme.headerPadH
                width: parent.width - 2 * Theme.headerPadH
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                text: "It applies at once. Larger edges take a little more room between windows."
                color: Theme.faded
                font.pixelSize: Theme.sizeLabel
            }
        }
    }
}
