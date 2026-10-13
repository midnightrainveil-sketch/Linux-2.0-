import QtQuick
import qs.theme

// Index card (section 7): the base of every widget and popup.
// paper.card fill, grain, cut edge, soft shadow, header band, then content,
// then an optional rule-separated footer row (e.g. Location | Singapore).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string number: ""
    property string footerLabel: ""
    property string footerValue: ""
    property int labelWidth: 96
    property int seed: 1
    property real lift: 1.0
    property color titleColor: Theme.graphite
    property alias header: header
    default property alias content: body.data

    implicitWidth: Theme.recordWidth
    implicitHeight: header.height + body.implicitHeight + (footer.visible ? footer.height + Theme.rule : 0) + 4

    Paper {
        anchors.fill: parent
        seed: root.seed
        lift: root.lift
    }

    HeaderBand {
        id: header
        visible: root.title !== ""
        height: visible ? implicitHeight : 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        title: root.title
        subtitle: root.subtitle
        number: root.number
        titleColor: root.titleColor
        seed: root.seed * 13
    }

    Column {
        id: body
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Rule {
        visible: footer.visible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.bottom: footer.top
        height: implicitHeight
        seed: root.seed * 17
    }

    DataRow {
        id: footer
        visible: root.footerLabel !== ""
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: parent.width
        label: root.footerLabel
        value: root.footerValue
        labelWidth: root.labelWidth
        last: true
        rowHeight: Theme.rowHeight + 4
    }
}
