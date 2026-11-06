import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Audio Archive, laid out to the reference card (485 x 226):
//   header band, rule at 42
//   the cover, printed in the archive's inks and framed (a cassette when
//   there is none) | artist, title, album
//   progress: 4 px accent fill on a 2 px track, times under it
// No. = release year of the current track.
// Under the progress line, between the times: previous, pause / play, next,
// drawn in pen like the wallpaper's plates; drag along the line to move
// through the song.
// Click the print to play / pause; click anywhere else on the card for the
// gramophone (the music in ~/Music); scroll over the card to skip.
IndexCard {
    id: card

    // the buttons work our own gramophone when it has a record on, else
    // whatever else is playing (a browser, Spotify)
    readonly property bool ours: Gramophone.loaded
    readonly property bool playing: ours ? Gramophone.playing : Media.playing
    readonly property bool going: ours || Media.active
    readonly property real at: ours ? Gramophone.position : Media.position
    readonly property real span: ours ? Gramophone.duration : Media.length
    function toggle(): void { ours ? Gramophone.toggle() : Media.toggle(); }
    function previous(): void { ours ? Gramophone.previous() : Media.previous(); }
    function next(): void { ours ? Gramophone.next() : Media.next(); }
    function seekTo(seconds: real): void { ours ? Gramophone.seekTo(seconds) : Media.seekTo(seconds); }
    readonly property string artist: ours ? (Gramophone.track?.artist || Gramophone.album?.artist || "") : Media.artist
    readonly property string song: ours ? (Gramophone.track?.title ?? Gramophone.path.split("/").pop()) : Media.title
    readonly property string record: ours ? (Gramophone.album?.name ?? "") : Media.album
    readonly property string year: ours ? String(Gramophone.album?.year ?? "").slice(0, 4) : Media.year

    // while the card shows our record, ask the gramophone where in it we are
    readonly property bool watching: visible && ours && !Desk.covered
    property bool counted: false
    onWatchingChanged: {
        if (watching === counted) return;
        Gramophone.watchers = Math.max(0, Gramophone.watchers + (watching ? 1 : -1));
        counted = watching;
    }
    Component.onDestruction: if (counted) Gramophone.watchers = Math.max(0, Gramophone.watchers - 1)

    // (under everything else, so the print keeps its own click, and a drag
    // still moves the card)
    MouseArea {
        parent: card
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("phonograph")
    }

    title: Flavour.word("audioTitle", "Audio Archive")
    number: card.year !== "" ? card.year : (card.going ? "----" : "")
    seed: 303
    implicitHeight: 226

    Item {
        width: card.width
        height: 181

        // the print: the cover, printed in the archive's inks (archive-print)
        // and framed; with no cover, a cassette, its reels turning while
        // music plays
        Item {
            id: photo
            x: 27
            y: 61 - 45
            width: 134
            height: 140

            // the cover as the player gives it, and its print
            readonly property string cover: Gramophone.loaded && Gramophone.cover !== "" ? "file://" + Gramophone.cover : Media.art
            property string printed: ""
            property string printedFor: ""
            onCoverChanged: {
                if (cover === "") { printed = ""; printedFor = ""; return; }
                if (cover === printedFor) return;
                printer.running = false;
                printer.command = ["archive-print", cover];
                printer.running = true;
            }
            Component.onCompleted: coverChanged()
            Process {
                id: printer
                stdout: StdioCollector {
                    onStreamFinished: {
                        const path = text.trim();
                        if (path !== "") { photo.printed = "file://" + path; photo.printedFor = photo.cover; }
                    }
                }
            }
            readonly property bool framed: card.going && cover !== "" && art.status === Image.Ready

            Cassette {
                id: tape
                x: -8
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4
                width: 150
                visible: !photo.framed
                title: card.going ? card.song : ""
                playing: card.playing && !Desk.covered
                progress: card.span > 0 ? Math.max(0, Math.min(1, card.at / card.span)) : 0.2
            }

            // the frame: a thin dark moulding, a paper mount, the print
            Item {
                id: frame
                anchors.centerIn: parent
                width: 132
                height: 132
                visible: photo.framed
                Rectangle {
                    anchors.fill: parent
                    color: Theme.night > 0.5 ? "#141c2c" : "#4a3f36"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                    // the moulding's lit inner edge
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                    }
                }
                Rectangle {
                    id: mount
                    anchors.fill: parent
                    anchors.margins: 4
                    color: Theme.night > 0.5 ? "#c9c4b8" : "#e8e2d6"
                }
                Image {
                    id: art
                    anchors.fill: mount
                    anchors.margins: 9
                    source: photo.printed
                    sourceSize: Qt.size(280, 280)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                // the print's own edge, pressed into the mount
                Rectangle {
                    anchors.fill: art
                    anchors.margins: -1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                }
                Rectangle {
                    anchors.fill: art
                    visible: Theme.night > 0.5
                    color: Qt.rgba(0.05, 0.08, 0.16, 0.18)
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.shadow
                    blurMax: 24
                    shadowBlur: 0.4
                    shadowVerticalOffset: 3.5
                    shadowHorizontalOffset: 2
                    shadowOpacity: 0.95
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.toggle()
            }
        }

        Column {
            x: 184
            y: 72 - 45 - 11
            width: card.width - x - Theme.headerPadH
            spacing: 9
            InkText {
                width: parent.width
                visible: !card.going || card.artist !== ""
                text: card.going ? card.artist : "No recording playing."
                color: card.going ? Theme.soft : Theme.faded
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: card.going
                text: card.song
                color: Theme.graphite
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: card.going && card.record !== ""
                text: card.record
                color: Theme.soft
                elide: Text.ElideRight
            }
        }

        // progress
        Item {
            id: progress
            x: 185
            y: 171 - 45 - 2
            width: 459 - 185
            height: 4
            visible: card.going
            readonly property real shown: scrub.pressed ? scrub.f
                : (card.span > 0 ? Math.max(0, Math.min(1, card.at / card.span)) : 0)
            Rectangle { y: 1; width: parent.width; height: 2; color: Theme.ruleFaint; opacity: 0.9 }
            Rectangle {
                width: parent.width * progress.shown
                height: 4
                color: Theme.accent
            }
            // a small nib where you are, while you hold it
            Rectangle {
                visible: scrub.pressed || scrub.containsMouse
                x: parent.width * progress.shown - 3
                y: -3
                width: 6; height: 10; radius: 1.5
                color: Theme.accent
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
            }
            MouseArea {
                id: scrub
                anchors.fill: parent
                anchors.topMargin: -7
                anchors.bottomMargin: -5
                enabled: card.span > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property real f: 0
                function fAt(m) { return Math.max(0, Math.min(1, m.x / width)); }
                onPressed: m => f = fAt(m)
                onPositionChanged: m => { if (pressed) f = fAt(m); }
                onReleased: card.seekTo(f * card.span)
            }
        }
        InkText {
            id: elapsed
            visible: card.going
            x: progress.x
            y: 194 - 45 - 9
            text: Media.time(scrub.pressed ? scrub.f * card.span : card.at)
            font.pixelSize: Theme.sizeSmall
        }
        InkText {
            visible: card.going
            x: progress.x + progress.width - width + 2
            y: 194 - 45 - 9
            text: Media.time(card.span)
            font.pixelSize: Theme.sizeSmall
        }

        // previous, pause / play, next: drawn in pen, level with the times
        Row {
            visible: card.going
            x: progress.x + progress.width / 2 - width / 2
            y: elapsed.y + elapsed.height / 2 - height / 2
            spacing: 12
            Repeater {
                model: ["previous", "toggle", "next"]
                InkButton {
                    required property string modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    kind: modelData
                    size: modelData === "toggle" ? 26 : 22
                    seed: 331 + index * 17
                    playing: card.playing
                    onClicked: {
                        if (modelData === "previous") card.previous();
                        else if (modelData === "next") card.next();
                        else card.toggle();
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => e.angleDelta.y > 0 ? card.previous() : card.next()
    }
}
