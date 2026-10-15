import QtQuick
import qs.theme
import qs.services
import qs.components

// One month of the ledger, typed: the week number in the first column, then
// Monday..Sunday over six weeks; days of the months either side in faint
// ink, today circled in the blue pencil ring.
Grid {
    id: root

    property date first: new Date()      // the 1st of the month shown
    property int cellW: 40
    property int cellH: 28
    property int fontSize: Theme.sizeData
    property int weekSize: Theme.sizeLabel
    property var weekdays: []            // e.g. ["Wk", "Mo", ...]: a row on top
    property int seed: 510

    columns: 8
    columnSpacing: 0
    rowSpacing: 2

    readonly property var cells: {
        const first = root.first;
        const offset = (first.getDay() + 6) % 7;
        const now = Clock.now;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                isToday: d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate(),
                week: Clock.isoWeek(d)
            });
        }
        return out;
    }

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
            readonly property var info: root.cells[Math.floor(index / 8) * 7 + Math.max(0, index % 8 - 1)]
            width: root.cellW; height: root.cellH

            InkText {
                anchors.centerIn: parent
                text: cell.isWeek ? String(cell.info.week) : String(cell.info.day)
                font.pixelSize: cell.isWeek ? root.weekSize : root.fontSize
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
                seed: root.seed + cell.index
            }
            PencilRing {
                visible: !cell.isWeek && cell.info.isToday
                anchors.centerIn: parent
                width: Math.min(root.cellW - 6, root.cellH + 6) ; height: root.cellH - 2
                seed: Clock.dayOfYear
            }
        }
    }
}
