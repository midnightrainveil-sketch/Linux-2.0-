import QtQuick
import qs.theme

// The determination under a figure, written as on the sheet's specimen:
// the name in a copperplate hand, then the authority, the family and the
// common name typed beneath it.
//
//   Phonographum vulgare
//   Berliner, 1887.
//   Machinae sonorae
//   Common gramophone.
Column {
    id: root

    property string name: ""
    property var lines: []
    property string figure: ""            // "Fig. 1." typed before the name
    spacing: 2

    Row {
        spacing: 12
        InkText {
            visible: root.figure !== ""
            anchors.baseline: nameText.baseline
            text: root.figure
            font.pixelSize: Theme.sizeSmall
            color: Theme.faded
        }
        Text {
            id: nameText
            text: root.name
            font.family: Theme.script
            font.pixelSize: 30
            color: Theme.graphite
            renderType: Text.QtRendering
        }
    }
    Repeater {
        model: root.lines
        InkText {
            required property string modelData
            x: root.figure !== "" ? 4 : 0
            text: modelData
            font.pixelSize: Theme.sizeSmall
            color: Theme.soft
        }
    }
}
