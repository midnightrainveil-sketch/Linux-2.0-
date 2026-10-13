import QtQuick
import qs.theme
import "Rand.js" as Rand

// One row of a Data table: label in ink.faded | vertical rule | value in
// ink.soft. Put any item inside to replace the typed value (toggles, sliders).
Item {
    id: root

    property string label: ""
    property string value: ""
    property color valueColor: Theme.soft
    property int labelWidth: 96
    property bool ruled: true          // rule.faint line under the row
    property bool last: false
    property int seed: Rand.hash(label)
    property int rowHeight: Theme.rowHeight
    default property alias slot: valueSlot.data

    width: parent ? parent.width : 300
    implicitHeight: rowHeight

    InkText {
        id: labelText
        anchors.left: parent.left
        anchors.leftMargin: Theme.headerPadH
        anchors.right: column.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.faded
        font.pixelSize: Theme.sizeLabel
        elide: Text.ElideRight
    }

    Rule {
        id: column
        vertical: true
        x: root.labelWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: implicitWidth
        color: Theme.ruleInk
        seed: root.seed
    }

    InkText {
        visible: valueSlot.children.length === 0
        anchors.left: column.right
        anchors.leftMargin: Theme.headerPadH
        anchors.right: parent.right
        anchors.rightMargin: Theme.headerPadH
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.valueColor
        font.pixelSize: Theme.sizeData
        elide: Text.ElideRight
    }

    Item {
        id: valueSlot
        anchors.left: column.right
        anchors.leftMargin: Theme.headerPadH
        anchors.right: parent.right
        anchors.rightMargin: Theme.headerPadH
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    Rule {
        visible: root.ruled && !root.last
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.bottom: parent.bottom
        height: implicitHeight
        color: Theme.ruleFaint
        weight: 1
        seed: root.seed + 3
    }

}
