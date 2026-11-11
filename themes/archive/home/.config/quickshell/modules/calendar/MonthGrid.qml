import QtQuick
import qs.theme
import qs.services
import qs.components

// One month of the ledger, typed: the week number in the first column, then
// Monday..Sunday over six weeks; days of the months either side in faint
// ink, today circled in the blue pencil ring.
Item {
    id: root

    property date first: new Date()      // the 1st of the month shown
    property int cellW: 40
    property int cellH: 28
    property int fontSize: Theme.sizeData
    property int weekSize: Theme.sizeLabel
    property var weekdays: []            // e.g. ["Wk", "Mo", ...]: a row on top
    property int seed: 510

    readonly property int gap: 2         // between the rows
    readonly property real headH: weekdays.length ? cellH - 4 + gap : 0

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    // the six weeks of days (worked out again when the date changes, not
    // every minute)
    readonly property int todayAt: {
        void Clock.dayOfYear;
        const now = new Date(), f = root.first;
        if (now.getFullYear() !== f.getFullYear() || now.getMonth() !== f.getMonth()) return -1;
        return (f.getDay() + 6) % 7 + now.getDate() - 1;
    }
    readonly property var cells: {
        const first = root.first;
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            out.push({ day: d.getDate(), inMonth: d.getMonth() === first.getMonth(), week: Clock.isoWeek(d) });
        }
        return out;
    }

    Grid {
        id: grid
        columns: 8
        columnSpacing: 0
        rowSpacing: root.gap

        Repeater {
            model: root.weekdays
            Item {
                required property string modelData
                required property int index
                width: root.cellW; height: root.cellH - 4
                InkText {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: root.weekSize
                    color: index === 0 ? Theme.faded : Theme.soft
                    font.bold: index !== 0
                }
            }
        }

        Repeater {
            model: 48
            Item {
                id: cell
                required property int index
                readonly property bool isWeek: index % 8 === 0
                readonly property int at: Math.floor(index / 8) * 7 + Math.max(0, index % 8 - 1)
                readonly property var info: root.cells[at]
                width: root.cellW; height: root.cellH

                InkText {
                    anchors.centerIn: parent
                    text: cell.isWeek ? String(cell.info.week) : String(cell.info.day)
                    font.pixelSize: cell.isWeek ? root.weekSize : root.fontSize
                    color: cell.isWeek ? Theme.faded
                         : !cell.isWeek && cell.at === root.todayAt ? Theme.accent
                         : cell.info.inMonth ? Theme.graphite : Theme.ruleFaint
                }
            }
        }
    }

    // the rule after the week numbers: one line down the six weeks
    Rule {
        vertical: true
        x: root.cellW - width
        y: root.headH
        width: implicitWidth
        height: 6 * root.cellH + 5 * root.gap
        weight: 1
        seed: root.seed
    }

    // today, circled in the blue pencil ring (one, where it is)
    PencilRing {
        visible: root.todayAt >= 0
        readonly property int row: Math.floor(Math.max(0, root.todayAt) / 7)
        readonly property int col: Math.max(0, root.todayAt) % 7 + 1
        width: Math.min(root.cellW - 6, root.cellH + 6)
        height: root.cellH - 2
        x: col * root.cellW + (root.cellW - width) / 2
        y: root.headH + row * (root.cellH + root.gap) + (root.cellH - height) / 2
        seed: Clock.dayOfYear
    }
}
