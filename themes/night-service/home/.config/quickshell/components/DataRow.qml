import QtQuick
import qs.theme
import "Rand.js" as Rand

// One row of a Data table, as on the reference: label | vertical rule | value,
// 38 px tall, with a ruled line underneath that stops at `ruleRight` (so a
// table can leave an empty column on the right, like the Time Record).
// Put any item inside to replace the typed value (toggles, sliders).
Item {
    id: root

    property string label: ""
    property string value: ""
    property color valueColor: Theme.soft
    property int labelWidth: 112          // x of the column rule
    property int valueGap: 20             // value text after the column rule
    property bool ruled: true             // the line under the row
    property bool last: false
    property real ruleRight: width - Theme.ruleInset
    property bool columnRule: true
    property int seed: Rand.hash(label)
    property int rowHeight: Theme.rowHeight
    property int fontSize: Theme.sizeData
    default property alias slot: valueSlot.data

    width: parent ? parent.width : 300
    implicitHeight: rowHeight

    InkText {
        id: labelText
        x: Theme.cardPad
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth - x - 8
        text: root.label
        color: Theme.labelInk
        font.pixelSize: root.fontSize
        elide: Text.ElideRight
    }

    Rule {
        id: column
        visible: root.columnRule
        vertical: true
        x: root.labelWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // the card's last row: stop inside its cut edge
        anchors.bottomMargin: root.last ? Math.max(0, Theme.edgeInset - 4) : 0
        width: implicitWidth
        seed: root.seed
    }

    InkText {
        visible: valueSlot.children.length === 0
        x: root.labelWidth + root.valueGap
        anchors.verticalCenter: parent.verticalCenter
        width: root.ruleRight - x - 8
        text: root.value
        color: root.valueColor
        font.pixelSize: root.fontSize
        elide: Text.ElideRight
    }

    Item {
        id: valueSlot
        x: root.labelWidth + root.valueGap
        width: root.ruleRight - x - 8
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    Rule {
        visible: root.ruled && !root.last
        x: Theme.ruleInset
        width: root.ruleRight - x
        anchors.bottom: parent.bottom
        height: implicitHeight
        weight: 1.3
        seed: root.seed + 3
    }
}
