import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// One album, filed as a herbarium sheet: the sleeve mounted in the middle
// with strips of linen tape (a pressed sprig when it has none), its tracks
// typed below as the sheet's annotations, and the label in the corner:
// album, collector (the artist), date, where it is filed.
Item {
    id: sheet

    width: 450
    height: 610

    property var album: null
    property int number: 0              // its place in the collection, from 1
    property int count: 0
    property int selected: 0            // the marked track (keyboard)
    property int playing: -1            // the track on the platter, if this album is on it
    property string emptyWhere: "~/Music"
    property bool reading: false

    signal picked(int track)

    readonly property bool empty: album === null
    readonly property int seed: Rand.hash(album?.key ?? "none") % 9973

    Paper {
        anchors.fill: parent
        seed: sheet.seed
        lift: 1.6
    }

    // ---------------------------------------------------------------- the heading
    InkText {
        x: Theme.cardPad
        y: 16
        text: "Phonographic Collection"
        caps: true
        tracking: 0.12
        font.pixelSize: 13
        color: Theme.soft
    }
    InkText {
        anchors.right: parent.right
        anchors.rightMargin: Theme.cardPad
        y: 16
        visible: sheet.count > 0
        text: "Folder " + String(sheet.number).padStart(2, "0") + " of " + String(sheet.count).padStart(2, "0")
        font.pixelSize: 13
        color: Theme.faded
    }
    Rule {
        x: Theme.ruleInset
        y: 42
        width: parent.width - 2 * Theme.ruleInset
        height: implicitHeight
        seed: 2201
    }

    // ---------------------------------------------------------------- the specimen
    Item {
        id: mount
        width: 216
        height: 216
        anchors.horizontalCenter: parent.horizontalCenter
        y: 60
        rotation: (Rand.make(sheet.seed)() - 0.5) * 3

        // the sleeve, as a print: a little faded, a little warm
        Item {
            anchors.fill: parent
            visible: art.status === Image.Ready
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.25)
            }
            Image {
                id: art
                anchors.fill: parent
                source: sheet.album?.cover ? "file://" + sheet.album.cover : ""
                sourceSize: Qt.size(432, 432)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: art
                source: art
                saturation: -0.55
                contrast: 0.05
                brightness: Theme.night > 0.5 ? -0.12 : 0.02
                shadowEnabled: true
                shadowBlur: 0.25
                shadowVerticalOffset: 2
                shadowHorizontalOffset: 1
                shadowOpacity: 0.35
            }
            Grain { anchors.fill: parent; strength: 1.8 }
        }

        // no sleeve: a pressed sprig
        Image {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            width: 190
            height: 190
            source: Qt.resolvedUrl("../../assets/sprig-wash.png")
            fillMode: Image.PreserveAspectFit
            opacity: sheet.empty ? 0.45 : 0.8
            asynchronous: true
        }

        // linen tape over the corners
        Tape { x: -20; y: -2; width: 58; height: 16; rotation: -42; seed: sheet.seed + 1; visible: art.status === Image.Ready }
        Tape { x: parent.width - 38; y: -2; width: 58; height: 16; rotation: 42; seed: sheet.seed + 2; visible: art.status === Image.Ready }
        Tape { x: -20; y: parent.height - 14; width: 58; height: 16; rotation: 42; seed: sheet.seed + 3; visible: art.status === Image.Ready }
        Tape { x: parent.width - 38; y: parent.height - 14; width: 58; height: 16; rotation: -42; seed: sheet.seed + 4; visible: art.status === Image.Ready }
        // and a stitch of thread over a sprig
        Tape { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.55; width: 44; height: 12; rotation: 8; seed: sheet.seed + 5; visible: art.status !== Image.Ready && !sheet.empty }
    }

    // ---------------------------------------------------------------- the annotations: tracks
    ListView {
        id: tracks
        visible: !sheet.empty
        x: 18
        y: 288
        width: parent.width - 36
        height: 6 * rowH
        readonly property int rowH: 30
        clip: true
        model: sheet.album?.tracks ?? []
        currentIndex: sheet.selected
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool isPlaying: sheet.playing === index
            readonly property bool marked: sheet.selected === index
            width: tracks.width
            height: tracks.rowH

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                color: Theme.paperRaised
                opacity: row.marked || hover.containsMouse ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }
            Rectangle { visible: row.marked; x: 0; y: 4; width: 2; height: parent.height - 8; color: Theme.accent }

            // a pencil tick against the one playing
            InkText {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: row.isPlaying
                text: "✓"
                color: Theme.madder
                font.pixelSize: 15
            }
            InkText {
                id: num
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                text: String(row.index + 1).padStart(2, "0")
                color: Theme.faded
                font.pixelSize: 14
            }
            InkText {
                anchors.left: num.right
                anchors.leftMargin: 12
                anchors.right: len.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.title
                color: row.isPlaying ? Theme.accent : Theme.graphite
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            InkText {
                id: len
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.length > 0 ? Media.time(row.modelData.length) : ""
                color: Theme.faded
                font.pixelSize: 14
            }
            Rule {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
                weight: 0.8
                color: Theme.ruleFaint
                seed: 2300 + row.index
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sheet.picked(row.index)
            }
        }
    }
    // more below
    InkText {
        visible: !sheet.empty && tracks.contentHeight > tracks.height
        anchors.right: tracks.right
        y: tracks.y + tracks.height + 1
        text: (tracks.atYEnd ? "" : "▾ ") + (sheet.album?.tracks?.length ?? 0) + " tracks"
        font.pixelSize: 12
        color: Theme.faded
    }

    // ---------------------------------------------------------------- nothing filed
    Column {
        visible: sheet.empty
        x: Theme.cardPad
        y: 300
        width: parent.width - 2 * Theme.cardPad
        spacing: 10
        InkText {
            width: parent.width
            text: sheet.reading ? "Reading the collection…" : "No recordings filed."
            color: Theme.graphite
        }
        InkText {
            visible: !sheet.reading
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Put each album in a folder of its own in " + sheet.emptyWhere + " (a cover.jpg in it becomes the sleeve), then open the gramophone again."
            color: Theme.faded
            font.pixelSize: 14
        }
    }

    // ---------------------------------------------------------------- the label
    Rectangle {
        id: label
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: 262
        height: 104
        color: Theme.paperRaised
        border.width: 1
        border.color: Theme.ruleInk
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: "transparent"
            border.width: 0.6
            border.color: Theme.ruleFaint
        }
        Grain { anchors.fill: parent; strength: 1.1 }

        Column {
            x: 10
            y: 8
            width: parent.width - 20
            spacing: 2
            InkText {
                width: parent.width
                text: "Herb. Sound Archive"
                caps: true
                tracking: 0.14
                font.pixelSize: 10
                color: Theme.soft
                horizontalAlignment: Text.AlignHCenter
            }
            Repeater {
                model: [
                    ["Album", sheet.album?.name ?? "—"],
                    ["Collector", sheet.album?.artist || "unknown"],
                    ["Date", sheet.album?.year || "n.d."],
                    ["Loc.", sheet.album?.where ?? sheet.emptyWhere]
                ]
                Row {
                    required property var modelData
                    spacing: 6
                    InkText {
                        width: 74
                        text: modelData[0]
                        font.pixelSize: 12
                        color: Theme.labelInk
                        font.italic: true
                    }
                    InkText {
                        width: label.width - 20 - 80
                        text: modelData[1]
                        font.pixelSize: 12
                        color: Theme.graphite
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    // the accession stamp
    Stamp {
        visible: !sheet.empty
        kind: "oval"
        number: String(sheet.number).padStart(4, "0")
        ink: Theme.accent
        seed: sheet.seed
        x: 30
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
    }
}
