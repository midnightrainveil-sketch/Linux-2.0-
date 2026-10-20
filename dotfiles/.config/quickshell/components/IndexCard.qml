import QtQuick
import qs.theme

// Index card (section 7): the base of every widget and popup, drawn to the
// reference: paper with a cut rim and soft shadow, a header band, content,
// then an optional rule-separated footer row (e.g. Location | Singapore).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string number: ""
    property string footerLabel: ""
    property string footerValue: ""
    property int labelWidth: 112
    property int footerHeight: 46
    property int seed: 1
    property real lift: 1.0
    property color titleColor: Theme.soft
    property alias header: header
    default property alias content: body.data

    implicitWidth: Theme.recordWidth
    implicitHeight: header.height + body.implicitHeight + (footer.visible ? footerHeight : 0)

    Paper {
        id: paper
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
        x: Theme.ruleInset
        width: parent.width - 2 * Theme.ruleInset
        y: footer.y - height / 2
        height: implicitHeight
        seed: root.seed * 17
    }

    DataRow {
        id: footer
        visible: root.footerLabel !== ""
        y: root.height - root.footerHeight
        width: parent.width
        rowHeight: root.footerHeight - 4
        label: root.footerLabel
        value: root.footerValue
        labelWidth: root.labelWidth
        last: true
    }

    // the aged edge, over everything on the card
    PaperOver {
        visible: paper.framed
        anchors.fill: parent
        z: 100
    }
}
