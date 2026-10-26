import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

// Audio Archive, laid out to the reference card (485 x 226):
//   header band, rule at 42
//   the cover as a grey print (a black record when there is none) | artist, title, album
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

    title: "Audio Archive"
    number: card.year !== "" ? card.year : (card.going ? "----" : "")
    seed: 303
    implicitHeight: 226

    Item {
        width: card.width
        height: 181

        // the print
        Item {
            id: photo
            x: 27
            y: 61 - 45
            width: 134
            height: 140

            Rectangle {
                anchors.fill: parent
                color: Theme.paperRaised
                visible: art.status === Image.Ready
            }
            // nothing to show: a black record, turning while music plays
            Item {
                id: blank
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 6
                height: width
                visible: art.status !== Image.Ready
                Canvas {
                    id: disc
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const c = width / 2;
                        g.fillStyle = "#141316";
                        g.beginPath(); g.arc(c, c, c - 1, 0, Math.PI * 2); g.fill();
                        // the grooves
                        g.lineWidth = 0.6;
                        for (let r = c - 4; r > c * 0.38; r -= 2.2) {
                            g.strokeStyle = Qt.rgba(1, 1, 1, 0.035 + 0.03 * Math.abs(Math.sin(r * 0.7)));
                            g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.stroke();
                        }
                        // the label, plain paper, and the spindle hole
                        g.fillStyle = "#cfc9bf";
                        g.beginPath(); g.arc(c, c, c * 0.33, 0, Math.PI * 2); g.fill();
                        g.strokeStyle = "rgba(0,0,0,0.25)"; g.lineWidth = 1;
                        g.beginPath(); g.arc(c, c, c * 0.24, 0, Math.PI * 2); g.stroke();
                        g.fillStyle = "#141316";
                        g.beginPath(); g.arc(c, c, 3, 0, Math.PI * 2); g.fill();
                        // a mark on the label, so the turning shows
                        g.fillStyle = "rgba(122, 74, 70, 0.7)";
                        g.fillRect(c - 1, c - c * 0.3, 2, c * 0.12);
                    }
                    RotationAnimation on rotation {
                        // (each frame redraws the whole desk: not while it is covered)
                        running: card.playing && blank.visible && !Desk.covered
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 1800
                    }
                }
                // the light on it, which does not turn
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const c = width / 2;
                        const sheen = g.createConicalGradient(c, c, -Math.PI / 4);
                        sheen.addColorStop(0.0, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.07, "rgba(255,255,255,0.14)");
                        sheen.addColorStop(0.15, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.5, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.57, "rgba(255,255,255,0.09)");
                        sheen.addColorStop(0.65, "rgba(255,255,255,0)");
                        sheen.addColorStop(1.0, "rgba(255,255,255,0)");
                        g.fillStyle = sheen;
                        g.beginPath(); g.arc(c, c, c - 2, 0, Math.PI * 2); g.arc(c, c, c * 0.34, 0, Math.PI * 2, true); g.fill();
                    }
                }
            }
            Image {
                id: art
                anchors.fill: parent
                // our own player's track picture first, else what the player reports
                source: Gramophone.loaded && Gramophone.cover !== "" ? "file://" + Gramophone.cover : Media.art
                // a cover file can be 3000 px: decode it at the card's size
                sourceSize: Qt.size(280, 280)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: art
                source: art
                visible: art.status === Image.Ready
                saturation: -1.0
                contrast: 0.12
                brightness: Theme.night > 0.5 ? -0.08 : 0.0
            }
            Grain { anchors.fill: parent; strength: 1.6; visible: art.status === Image.Ready }
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
