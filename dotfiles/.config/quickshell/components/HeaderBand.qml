import QtQuick
import qs.theme

// Header band (section 7): bold caps title on the left, a vertical rule,
// then "No. 42817" on the right; a rule closes the band underneath.
// An optional sentence-case subtitle sits under the title ("Time Record.").
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string number: ""            // digits only; "No." is always written out
    property color titleColor: Theme.graphite
    property int seed: 11

    implicitHeight: titleCol.implicitHeight + 2 * Theme.headerPadV + Theme.rule

    Column {
        id: titleCol
        anchors.left: parent.left
        anchors.leftMargin: Theme.headerPadH
        anchors.right: divider.left
        anchors.rightMargin: Theme.headerPadH
        anchors.top: parent.top
        anchors.topMargin: Theme.headerPadV
        spacing: 1

        InkText {
            width: parent.width
            text: root.title
            caps: true
            tracking: Theme.trackTitle
            color: root.titleColor
            font.pixelSize: Theme.sizeTitle
            font.bold: true
            elide: Text.ElideRight
        }
        InkText {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            color: Theme.soft
            font.pixelSize: Theme.sizeLabel
            elide: Text.ElideRight
        }
    }

    Rule {
        id: divider
        visible: root.number !== ""
        vertical: true
        seed: root.seed + 1
        anchors.right: numberText.left
        anchors.rightMargin: Theme.headerPadH
        anchors.top: parent.top
        anchors.bottom: bottomRule.top
        width: implicitWidth
    }

    InkText {
        id: numberText
        visible: root.number !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.headerPadH + 2
        anchors.top: parent.top
        anchors.topMargin: Theme.headerPadV
        text: "No. " + root.number
        color: Theme.graphite
        font.pixelSize: Theme.sizeNumber
        font.bold: true
    }

    Rule {
        id: bottomRule
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.bottom: parent.bottom
        height: implicitHeight
        seed: root.seed + 2
    }
}
