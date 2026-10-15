import QtQuick
import qs.theme

// A plate from the archive's own volumes, the way the sheet on the desk is
// laid out: a caps heading underlined in pencil with its sentence under it,
// "Tab." on the right, a ruled line; then what is mounted on it; and at the
// foot, the key to the plate in small type. The objects (the gramophone,
// the typewriter) are figures on such a plate, not things lying loose.
//
//   heading  "SOUND ARCHIVE"     subheading "Phonograph."
//   tab      "Tab. I."           legend     [["Return", "play"], ...]
Item {
    id: root

    property string heading: ""
    property string subheading: ""
    property string tab: ""
    property var legend: []
    property int seed: 3100
    property real lift: 1.8
    readonly property int headerHeight: 74
    readonly property int footerHeight: 44
    default property alias content: body.data

    Paper {
        anchors.fill: parent
        seed: root.seed
        lift: root.lift
        color: Theme.paperRaised
    }

    // ---- the heading, as on the sheet: FLORA EUROPAEA / Herbarium.
    InkText {
        id: headingText
        x: 36
        y: 20
        text: root.heading
        caps: true
        tracking: 0.12
        font.pixelSize: Theme.sizeTitle + 1
        color: Theme.graphite
    }
    InkText {
        id: subText
        x: 36
        y: headingText.y + headingText.height + 3
        text: root.subheading
        font.pixelSize: Theme.sizeSmall
        color: Theme.soft
    }
    Rule {
        x: 34
        y: subText.y + subText.height + 1
        width: Math.max(headingText.width, subText.width) + 4
        height: implicitHeight
        weight: 1
        seed: root.seed + 1
    }
    InkText {
        anchors.right: parent.right
        anchors.rightMargin: 38
        y: headingText.y
        text: root.tab
        font.pixelSize: Theme.sizeSmall
        color: Theme.soft
    }
    Rule {
        x: Theme.ruleInset + 8
        width: parent.width - 2 * (Theme.ruleInset + 8)
        y: root.headerHeight - height / 2
        height: implicitHeight
        seed: root.seed + 2
    }

    Item {
        id: body
        x: 0
        y: root.headerHeight
        width: parent.width
        height: parent.height - root.headerHeight - root.footerHeight
    }

    // ---- the key to the plate
    Rule {
        x: Theme.ruleInset + 8
        width: parent.width - 2 * (Theme.ruleInset + 8)
        y: parent.height - root.footerHeight
        height: implicitHeight
        color: Theme.ruleFaint
        weight: 1
        seed: root.seed + 3
    }
    Row {
        x: 36
        y: parent.height - root.footerHeight + (root.footerHeight - height) / 2
        spacing: 26
        Repeater {
            model: root.legend
            Row {
                required property var modelData
                spacing: 7
                InkText {
                    text: modelData[0]
                    font.pixelSize: Theme.sizeSmall - 2
                    font.bold: true
                    color: Theme.soft
                }
                InkText {
                    text: modelData[1]
                    font.pixelSize: Theme.sizeSmall - 2
                    color: Theme.faded
                }
            }
        }
    }
}
