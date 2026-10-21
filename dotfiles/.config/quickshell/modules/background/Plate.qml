import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// The wallpaper: one plate on the sheet (section 13). Two kinds of plate:
//   a whole sheet ("sheet": true): a finished picture with its own labels,
//     shown to fill the screen, crossfading to its cyanotype print at night;
//   a drawing alone: the shell types the labels on top so they stay sharp
//     and live (header, Tab. number, Latin name, specimen label, Specimen No.
//     and stamp). The centre third belongs to the specimen.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "archive-plate"
    color: Theme.paperBase

    readonly property real sheetW: width
    readonly property real sheetH: height - Theme.barHeight      // the sheet above the footer strip
    readonly property int plateSeed: Rand.hash(Plates.current + Plates.number)

    // the desk lamp follows the pointer across the bare desk (services/Lamp.qml)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: mouse => { if (Lamp.isOn && Theme.night > 0.5) Lamp.moveTo(win.modelData?.name ?? "", mouse.x, mouse.y); }
    }

    // ------------------------------------------------------------ a whole sheet
    Image {
        id: dayImg
        anchors.fill: parent
        visible: Plates.sheet && !Theme.folio
        source: Plates.sheetDay
        fillMode: Image.PreserveAspectCrop
        // the sheet is made at the screen's own size (import_wallpaper):
        // drawn straight, no resampling first and no mipmaps, which soften
        // fine pencil lines even when the picture barely shrinks
        asynchronous: true
        smooth: true
        mipmap: false
        cache: false
    }
    // Folio: the drawing's ink a step deeper (the paper's tone kept: the
    // brightness takes back what the contrast adds to it)
    BrightnessContrast {
        anchors.fill: parent
        visible: Plates.sheet && Theme.folio
        source: dayImg
        brightness: -0.115 * Theme.folioAmount
        contrast: 0.14 * Theme.folioAmount
    }
    Image {
        anchors.fill: parent
        visible: Plates.sheet && opacity > 0.003
        opacity: Theme.night
        source: Plates.sheetNight
        fillMode: Image.PreserveAspectCrop
        // the sheet is made at the screen's own size (import_wallpaper):
        // drawn straight, no resampling first and no mipmaps, which soften
        // fine pencil lines even when the picture barely shrinks
        asynchronous: true
        smooth: true
        mipmap: false
        cache: false
    }

    // ------------------------------------------------------------ the month's pressed specimen
    // A small pressed plant laid in the empty bottom-left corner of the
    // sheet, a different one each month, held by a strip of tape, with its
    // name typed under it (assets/specimens: tools/import_specimens.py, the
    // names in specimens.json). At night it is printed pale, like the sheet.
    Item {
        id: specimen
        readonly property int month: Clock.now.getMonth()           // 0 = January
        property var names: []
        readonly property var entry: names[month] ?? null
        visible: art.status === Image.Ready
        x: 72
        y: win.sheetH - 74 - art.height        // below the desk terminal, above the bar
        width: art.width
        height: art.height + 40
        rotation: -4

        FileView {
            path: Qt.resolvedUrl("../../assets/specimens/specimens.json").toString().replace("file://", "")
            onLoaded: { try { specimen.names = JSON.parse(text()); } catch (e) {} }
        }

        Image {
            id: art
            height: Math.round(win.sheetH * 0.215)
            width: sourceSize.height > 0 ? Math.round(height * sourceSize.width / sourceSize.height) : 0
            source: Qt.resolvedUrl("../../assets/specimens/" + String(specimen.month + 1).padStart(2, "0") + ".png")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            visible: false
        }
        // by day as drawn; by night a pale print of it
        Item {
            width: art.width
            height: art.height
            Image { anchors.fill: parent; source: art.source; mipmap: true; smooth: true; opacity: 1 - Theme.night }
            ColorOverlay { anchors.fill: parent; source: art; color: Qt.rgba(0.85, 0.89, 0.95, 0.85); opacity: Theme.night; visible: Theme.night > 0.01 }
        }
        Tape {
            x: art.width * 0.5 - width / 2
            y: art.height * 0.62
            width: Math.max(54, art.width * 0.42)
            height: 18
            rotation: 9
            seed: 77 + specimen.month
        }
        InkText {
            visible: specimen.entry !== null
            x: 4
            y: art.height + 10
            text: specimen.entry ? specimen.entry.month + "  " + specimen.entry.latin + "." : ""
            font.pixelSize: 14
            font.italic: true
            color: Theme.soft
            rotation: 2
        }
    }

    // Folio: daylight across the sheet, brighter from the top left, and a
    // vignette darkening it toward the edges (static: drawn once)
    Item {
        anchors.fill: parent
        visible: Theme.folio
        RadialGradient {
            anchors.fill: parent
            horizontalOffset: -parent.width * 0.28
            verticalOffset: -parent.height * 0.30
            horizontalRadius: parent.width * 0.75
            verticalRadius: parent.height * 0.9
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.99, 0.96, 0.16 * Theme.folioAmount) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        RadialGradient {
            anchors.fill: parent
            horizontalRadius: parent.width * 0.78
            verticalRadius: parent.height * 0.82
            gradient: Gradient {
                // the vignette: the sheet darkening toward its edges
                GradientStop { position: 0.36; color: "transparent" }
                GradientStop { position: 0.72; color: Qt.rgba(0.12, 0.11, 0.13, 0.18 * Theme.folioAmount) }
                GradientStop { position: 1.0; color: Qt.rgba(0.12, 0.11, 0.13, 0.44 * Theme.folioAmount) }
            }
        }
    }

    // ------------------------------------------------------------ a drawing, with typed labels
    Item {
        anchors.fill: parent
        visible: !Plates.sheet

        // ------------------------------------------------------------ paper
        Grain { anchors.fill: parent; strength: 1.0 }

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
                x: (index % 2 === 0 ? 0.04 + v[1] * 0.28 : 0.68 + v[1] * 0.28) * win.sheetW
                y: (0.05 + v[2] * 0.88) * win.sheetH
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
            x: box[0] * win.sheetW
            y: box[1] * win.sheetH
            width: (box[2] - box[0]) * win.sheetW
            height: (box[3] - box[1]) * win.sheetH

            Image {
                id: ink
                anchors.fill: parent
                source: Plates.folder === "" || !Plates.metaLoaded || Plates.sheet ? "" : Plates.folder + "ink.png"
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
                    font.pixelSize: 14
                    color: Theme.soft
                }
            }
        }

        // ------------------------------------------------------------ header (top centre)
        Column {
            x: 0.388 * win.sheetW
            y: 0.040 * win.sheetH
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
                font.pixelSize: 15
                color: Theme.soft
            }
            Rule { width: 160; height: implicitHeight; weight: 1.2; seed: 3 }
        }

        InkText {
            x: 0.648 * win.sheetW
            y: 0.042 * win.sheetH
            text: "Tab. " + Clock.tabNumeral + "."
            font.pixelSize: 15
            color: Theme.soft
        }

        // ------------------------------------------------------------ name (lower left of the stem)
        Column {
            x: 0.283 * win.sheetW
            y: 0.705 * win.sheetH
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
                InkText { text: Plates.authority; color: Theme.soft; font.pixelSize: 15 }
                InkText { text: Plates.family; color: Theme.soft; font.pixelSize: 15 }
                InkText { text: Plates.common; color: Theme.soft; font.pixelSize: 15 }
            }
        }

        // ------------------------------------------------------------ stamp (lower left)
        Stamp {
            x: 0.262 * win.sheetW
            y: 0.84 * win.sheetH
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
            x: 0.552 * win.sheetW
            y: 0.80 * win.sheetH
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
                            font.pixelSize: 14
                            color: Theme.soft
                        }
                        InkText {
                            text: Plates.label[modelData] ?? ""
                            font.pixelSize: 14
                            color: Theme.soft
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ Specimen No. (vertical, right of the plate)
        Rule {
            x: 0.698 * win.sheetW
            y: 0.63 * win.sheetH
            height: 0.30 * win.sheetH
            width: implicitWidth
            vertical: true
            weight: 1.1
            seed: 81
        }
        InkText {
            x: 0.703 * win.sheetW
            y: 0.82 * win.sheetH
            rotation: -90
            transformOrigin: Item.TopLeft
            text: "Specimen No. " + Plates.number
            font.pixelSize: 14
            color: Theme.soft
        }
    }
}
