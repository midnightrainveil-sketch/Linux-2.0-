import QtQuick
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// The wallpaper: one plate on the sheet (section 13). The plate image holds
// no text; the shell types the labels on top so they stay sharp and live:
// header, Tab. number, Latin name, specimen label, Specimen No. and stamp.
// The centre third belongs to the specimen; the side thirds stay empty.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "archive-plate"
    color: Theme.paperBase

    readonly property real W: width
    readonly property real H: height - Theme.barHeight      // the sheet above the footer strip
    readonly property int plateSeed: Rand.hash(Plates.current + Plates.number)

    // ------------------------------------------------------------ paper
    Grain { anchors.fill: parent; strength: 1.15 }

    // foxing: 3-6 small age spots, never on cards
    Repeater {
        model: 3 + (win.plateSeed % 4)
        Rectangle {
            required property int index
            // six stable random numbers per spot
            readonly property var v: {
                const r = Rand.make(win.plateSeed + index * 31);
                return [r(), r(), r(), r(), r(), r()];
            }
            readonly property real s: 2 + v[0] * 5
            x: (index % 2 === 0 ? 0.04 + v[1] * 0.28 : 0.68 + v[1] * 0.28) * win.W
            y: (0.05 + v[2] * 0.88) * win.H
            width: s; height: s * (0.7 + v[3] * 0.5)
            radius: s / 2
            color: Theme.night > 0.5 ? Qt.rgba(0.9, 0.85, 0.75, 1) : "#8a6e4b"
            opacity: (0.10 + v[4] * 0.16) * (1 - 0.5 * Theme.night)
            rotation: v[5] * 180
        }
    }

    // ------------------------------------------------------------ the plate
    Item {
        id: plateBox
        readonly property var box: Plates.field("box", [0.375, 0.06, 0.665, 0.95])
        x: box[0] * win.W
        y: box[1] * win.H
        width: (box[2] - box[0]) * win.W
        height: (box[3] - box[1]) * win.H

        Image {
            id: ink
            anchors.fill: parent
            source: Plates.folder === "" ? "" : Plates.folder + "ink.png"
            fillMode: Image.PreserveAspectFit
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            smooth: true
            mipmap: true
            visible: false
        }
        Image {
            id: wash
            anchors.fill: parent
            source: Plates.hasWash && Plates.folder !== "" ? Plates.folder + "wash.png" : ""
            fillMode: Image.PreserveAspectFit
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            visible: false
        }
        Image {
            id: silhouette
            anchors.fill: parent
            source: Plates.hasSilhouette && Plates.folder !== "" ? Plates.folder + "silhouette.png" : ""
            fillMode: Image.PreserveAspectFit
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            visible: false
        }

        // cyanotype photogram: the plant's shadow, printed pale (night only)
        ColorOverlay {
            anchors.fill: parent
            source: silhouette
            color: Theme.graphite
            opacity: 0.16 * Theme.night
            visible: opacity > 0.005 && silhouette.status === Image.Ready
        }
        // pale blue watercolour wash on the flowers (day only)
        ColorOverlay {
            anchors.fill: parent
            source: wash
            color: Theme.day.wash
            opacity: 0.42 * (1 - Theme.night)
            visible: opacity > 0.005 && wash.status === Image.Ready
        }
        // the drawing itself, in whatever ink the hour calls for
        ColorOverlay {
            anchors.fill: parent
            source: ink
            color: Theme.graphite
            opacity: 0.92
        }

        // tape strips holding the specimen down
        Repeater {
            model: Plates.tapes
            Tape {
                required property var modelData
                required property int index
                x: modelData.x * plateBox.width - width / 2
                y: modelData.y * plateBox.height - height / 2
                width: (modelData.w ?? 0.13) * plateBox.width
                height: 20
                rotation: modelData.angle ?? 0
                seed: 50 + index
            }
        }

        // scale marks beside the detail studies: 1:1, 2:1
        Repeater {
            model: Plates.marks
            InkText {
                required property var modelData
                x: modelData.x * plateBox.width
                y: modelData.y * plateBox.height
                text: modelData.text
                font.pixelSize: Theme.sizeLabel
                color: Theme.soft
            }
        }
    }

    // ------------------------------------------------------------ header (top centre)
    Column {
        x: 0.388 * win.W
        y: 0.040 * win.H
        spacing: 3
        InkText {
            text: Plates.region
            caps: true
            tracking: 0.12
            font.pixelSize: 13
            color: Theme.graphite
        }
        InkText {
            text: Plates.field("subtitle", "Archivum.")
            font.pixelSize: Theme.sizeData
            color: Theme.soft
        }
        Rule { width: 160; height: implicitHeight; weight: 1.2; seed: 3 }
    }

    InkText {
        x: 0.648 * win.W
        y: 0.042 * win.H
        text: "Tab. " + Clock.tabNumeral + "."
        font.pixelSize: Theme.sizeData
        color: Theme.soft
    }

    // ------------------------------------------------------------ name (lower left of the stem)
    Column {
        x: 0.283 * win.W
        y: 0.705 * win.H
        spacing: 2
        visible: Plates.latin !== ""

        Text {
            text: Plates.latin
            font.family: Theme.script
            font.pixelSize: 34          // the mockup reads larger than the 22 px shell token
            color: Theme.graphite
            renderType: Text.QtRendering
        }
        Column {
            leftPadding: 16
            topPadding: 2
            spacing: 4
            InkText { text: Plates.authority; color: Theme.soft }
            InkText { text: Plates.family; color: Theme.soft }
            InkText { text: Plates.common; color: Theme.soft }
        }
    }

    // ------------------------------------------------------------ stamp (lower left)
    Stamp {
        x: 0.262 * win.W
        y: 0.84 * win.H
        scale: 1.25
        transformOrigin: Item.TopLeft
        number: Plates.number
        seed: win.plateSeed % 1000
        ink: Theme.night > 0.5 ? Theme.graphite : Theme.accent
        opacity: Theme.night > 0.5 ? 0.45 : 0.8
    }

    // ------------------------------------------------------------ specimen label (lower right)
    Item {
        id: label
        x: 0.552 * win.W
        y: 0.80 * win.H
        width: labelRows.implicitWidth + 28
        height: labelRows.implicitHeight + 20

        Rule { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; vertical: true; width: implicitWidth; weight: 1.1; seed: 71 }
        Rule { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: implicitHeight; weight: 1.1; seed: 72 }

        Column {
            id: labelRows
            x: 14
            y: 11
            spacing: 5
            Repeater {
                model: ["loc", "hab", "leg", "det", "dat"]
                Row {
                    required property string modelData
                    spacing: 14
                    InkText {
                        width: 34
                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1) + "."
                        font.pixelSize: Theme.sizeLabel
                        color: Theme.soft
                    }
                    InkText {
                        text: Plates.label[modelData] ?? ""
                        font.pixelSize: Theme.sizeLabel
                        color: Theme.soft
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ Specimen No. (vertical, right of the plate)
    Rule {
        x: 0.698 * win.W
        y: 0.63 * win.H
        height: 0.30 * win.H
        width: implicitWidth
        vertical: true
        weight: 1.1
        seed: 81
    }
    InkText {
        x: 0.703 * win.W
        y: 0.82 * win.H
        rotation: -90
        transformOrigin: Item.TopLeft
        text: "Specimen No. " + Plates.number
        font.pixelSize: Theme.sizeLabel
        color: Theme.soft
    }
}
