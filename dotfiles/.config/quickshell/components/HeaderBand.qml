import QtQuick
import qs.theme

// Header band (section 7), measured off the reference cards: caps title in
// regular weight on the left, an optional sentence-case subtitle under it,
// a vertical rule running up to the card's top edge, "No. 42817" on the
// right, and a rule closing the band, inset from the card edges.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string number: ""            // digits only; "No." is always written out
    property color titleColor: Theme.soft
    property int seed: 11

    implicitHeight: subtitle !== "" ? Theme.headerHeight : 45

    InkText {
        id: titleText
        x: Theme.cardPad
        y: root.subtitle !== "" ? 12 : (root.implicitHeight - height) / 2 + 1
        width: divider.x - x - 12
        text: root.title
        caps: true
        tracking: Theme.trackTitle
        color: Theme.fc(root.titleColor, Theme.graphite)
        font.pixelSize: Theme.sizeTitle
        font.bold: Theme.folio
        elide: Text.ElideRight
    }
    InkText {
        visible: root.subtitle !== ""
        x: Theme.cardPad + 1
        y: 33
        width: divider.x - x - 12
        text: root.subtitle
        color: Theme.soft
        font.pixelSize: Theme.sizeTitle - 1
        elide: Text.ElideRight
    }

    Rule {
        id: divider
        visible: root.number !== ""
        vertical: true
        seed: root.seed + 1
        x: root.number !== "" ? numberText.x - 28 : root.width
        y: Theme.edgeInset          // inside the card's cut edge
        height: bottomRule.y - y + 1
        width: implicitWidth
    }

    InkText {
        id: numberText
        visible: root.number !== ""
        x: root.width - Theme.headerPadH - width
        y: titleText.y
        text: "No. " + root.number
        color: Theme.fc(Theme.soft, Theme.madder)
        font.pixelSize: Theme.sizeNumber
        tracking: 0.04
    }

    Rule {
        id: bottomRule
        x: Theme.ruleInset
        width: root.width - 2 * Theme.ruleInset
        y: root.implicitHeight - height / 2
        height: implicitHeight
        seed: root.seed + 2
    }
}
