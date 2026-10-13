import QtQuick
import qs.theme
import qs.services
import qs.components

// Ledger (calendar): rises from the bar's date. Month grid typed in Courier,
// week numbers in the first column, today circled in a blue pencil ring.
// Scroll or use the arrow keys to turn the pages.
BarPopup {
    id: popup
    name: "ledger"
    side: "right"

    property int monthOffset: 0
    readonly property date base: {
        const n = Clock.now;
        return new Date(n.getFullYear(), n.getMonth() + monthOffset, 1);
    }
    readonly property var cells: {
        // Monday-first grid of 6 weeks: [{ day, inMonth, isToday, week }]
        const first = popup.base;
        const offset = (first.getDay() + 6) % 7;
        const start = new Date(first.getFullYear(), first.getMonth(), 1 - offset);
        const now = Clock.now;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                isToday: d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                week: Clock.isoWeek(d)
            });
        }
        return out;
    }

    onOpened: { monthOffset = 0; keys.forceActiveFocus(); }

    IndexCard {
        id: card
        width: 360
        title: "Ledger"
        subtitle: Qt.formatDate(popup.base, "MMMM yyyy") + "."
        number: Clock.pad(popup.base.getMonth() + 1, 2) + String(popup.base.getFullYear()).slice(2)
        seed: 505
        lift: 1.4

        Item {
            id: keys
            width: parent.width
            height: grid.height + 22
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) popup.monthOffset -= 1;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) popup.monthOffset += 1;
                else if (e.key === Qt.Key_Home) popup.monthOffset = 0;
                else if (e.key === Qt.Key_Escape) Panels.close();
            }
            WheelHandler { onWheel: e => popup.monthOffset += (e.angleDelta.y > 0 ? -1 : 1) }

            Grid {
                id: grid
                x: Theme.headerPadH - 4
                y: 12
                columns: 8
                columnSpacing: 0
                rowSpacing: 2

                readonly property int cw: (card.width - 2 * Theme.headerPadH + 8) / 8

                // header row
                Repeater {
                    model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Item {
                        required property string modelData
                        required property int index
                        width: grid.cw; height: 24
                        InkText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.sizeLabel
                            color: index === 0 ? Theme.faded : Theme.soft
                            font.bold: index !== 0
                        }
                    }
                }

                // 6 weeks: a week number, then 7 days
                Repeater {
                    model: 48
                    Item {
                        id: cell
                        required property int index
                        readonly property bool isWeek: index % 8 === 0
                        readonly property var info: popup.cells[Math.floor(index / 8) * 7 + Math.max(0, index % 8 - 1)]
                        width: grid.cw; height: 28

                        InkText {
                            anchors.centerIn: parent
                            text: cell.isWeek ? String(cell.info.week) : String(cell.info.day)
                            font.pixelSize: cell.isWeek ? Theme.sizeLabel : Theme.sizeData
                            color: cell.isWeek ? Theme.faded
                                 : cell.info.isToday ? Theme.accent
                                 : cell.info.inMonth ? Theme.graphite : Theme.ruleFaint
                        }
                        Rule {
                            visible: cell.isWeek
                            vertical: true
                            anchors.right: parent.right
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: implicitWidth
                            weight: 1
                            seed: 510 + cell.index
                        }
                        PencilRing {
                            visible: !cell.isWeek && cell.info.isToday
                            anchors.centerIn: parent
                            width: 30; height: 26
                            seed: Clock.dayOfYear
                        }
                    }
                }
            }
        }
    }
}
