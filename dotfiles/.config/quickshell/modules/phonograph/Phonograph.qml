import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components

// The Phonograph: the sound archive's gramophone, slid out onto the desk
// from the bar. On the left the collection: every album in ~/Music filed as
// a herbarium folder, its tab sticking out of the stack, the open one a
// sheet with the sleeve mounted like a specimen and its tracks typed under
// it. On the right the turntable. Pick a track and the record comes out of
// its folder onto the platter.
//
//   click a track, Return       play it            click a tab, Left / Right   another folder
//   Up / Down                   mark a track       Space, click the record     pause / play
//   N / P                       next / previous    , / .                       wind back / on
//   Escape, click outside       close (the music plays on)
PanelWindow {
    id: win

    readonly property string name: "phonograph"
    readonly property bool shown: Panels.open === name

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-phonograph"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || slide > 0.001
    mask: Region { item: win.shown ? catcher : null }

    // ---------------------------------------------------------------- what is shown
    property int folder: 0               // the open folder
    property int marked: 0               // the marked track in it

    readonly property var albums: Gramophone.albums
    readonly property var album: albums.length ? albums[Math.max(0, Math.min(folder, albums.length - 1))] : null

    // the platter: ours, or whatever else is playing (a browser, Spotify)
    readonly property bool ours: Gramophone.loaded
    readonly property bool other: !ours && Media.active

    // the open folder follows the record on the platter, until you leaf
    // through the folders yourself
    property bool leafed: false
    Connections {
        target: Gramophone
        function onAlbumIndexChanged() {
            if (!win.leafed && Gramophone.albumIndex >= 0) win.folder = Gramophone.albumIndex;
        }
        function onTrackIndexChanged() {
            if (win.folder === Gramophone.albumIndex && Gramophone.trackIndex >= 0) win.marked = Gramophone.trackIndex;
        }
    }

    onShownChanged: {
        if (shown) {
            leafed = false;
            Gramophone.readLibrary();
            Gramophone.watchers += 1;
            if (Gramophone.albumIndex >= 0) { folder = Gramophone.albumIndex; marked = Math.max(0, Gramophone.trackIndex); }
            keys.forceActiveFocus();
        } else {
            Gramophone.watchers = Math.max(0, Gramophone.watchers - 1);
        }
    }
    onAlbumsChanged: {
        if (folder >= albums.length) folder = Math.max(0, albums.length - 1);
        if (Gramophone.albumIndex >= 0 && !leafed) folder = Gramophone.albumIndex;
    }
    onFolderChanged: {
        marked = (folder === Gramophone.albumIndex) ? Math.max(0, Gramophone.trackIndex) : 0;
        if (shown) swap.restart();
    }

    function turn(by: int): void {
        if (albums.length === 0) return;
        leafed = true;
        folder = (folder + by + albums.length) % albums.length;
    }
    function mark(by: int): void {
        const n = album?.tracks?.length ?? 0;
        if (n > 0) marked = Math.max(0, Math.min(n - 1, marked + by));
    }
    function playMarked(t: int): void {
        if (!album) return;
        if (folder !== Gramophone.albumIndex) flight.start();
        Gramophone.play(folder, t);
    }
    function toggle(): void {
        if (ours) Gramophone.toggle();
        else if (other) Media.toggle();
        else if (album) playMarked(marked);
    }

    // ---------------------------------------------------------------- motion
    property real slide: shown ? 1 : 0
    Behavior on slide {
        NumberAnimation {
            duration: win.shown ? Theme.dur(520) : Theme.dur(260)
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.7
        }
    }

    // ---------------------------------------------------------------- the room
    Item { id: catcher; anchors.fill: parent }
    Rectangle {
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#050b16" : "#1e1d22"
        opacity: 0.22 * win.slide
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (Panels.open === win.name) Panels.close()
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape) Panels.close();
            else if (k === Qt.Key_Left || k === Qt.Key_PageUp) win.turn(-1);
            else if (k === Qt.Key_Right || k === Qt.Key_PageDown || k === Qt.Key_Tab) win.turn(1);
            else if (k === Qt.Key_Backtab) win.turn(-1);
            else if (k === Qt.Key_Up || k === Qt.Key_K) win.mark(-1);
            else if (k === Qt.Key_Down || k === Qt.Key_J) win.mark(1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.playMarked(win.marked);
            else if (k === Qt.Key_Space) win.toggle();
            else if (k === Qt.Key_N) win.ours ? Gramophone.next() : Media.next();
            else if (k === Qt.Key_P) win.ours ? Gramophone.previous() : Media.previous();
            else if (k === Qt.Key_Period) Gramophone.seek(10);
            else if (k === Qt.Key_Comma) Gramophone.seek(-10);
            else return;
            e.accepted = true;
        }
    }

    // ---------------------------------------------------------------- the plate
    // The gramophone is a figure on a plate of the sound archive's volume:
    // the plate slides up out of the bar, the collection and the machine
    // mounted on it, the machine's determination written under it.
    Item {
        id: plate
        width: stage.width + 2 * 44
        height: 74 + 18 + stage.height + 112 + 44
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(12, win.height - Theme.barHeight - height - 14) + (1 - win.slide) * (height + 60)
        opacity: Math.min(1, win.slide * 3)

        MouseArea { anchors.fill: parent }        // the plate itself does not close it

        PlateSheet {
            anchors.fill: parent
            heading: "Sound Archive"
            subheading: "The collection and the gramophone."
            tab: "Tab. " + Clock.roman(Math.max(1, win.folder + 1)) + "."
            seed: 3120
            legend: [["Return", "play"], ["Space", "pause"], ["← →", "folders"], ["↑ ↓", "tracks"],
                     ["N  P", "next, previous"], [",  .", "wind"], ["Esc", "close; the record plays on"]]
        }

        // the machine's determination, under its figure
        SpecimenNote {
            x: stage.x + deck.x + 6
            y: stage.y + stage.height + 14
            figure: "Fig. 2."
            name: "Phonographum vulgare"
            lines: ["Berliner, 1887.   Machinae sonorae.", "Common gramophone, seen from above."]
        }
        InkText {
            anchors.right: parent.right
            anchors.rightMargin: 46
            y: stage.y + stage.height + 30
            text: "1 : 4"
            font.pixelSize: Theme.sizeSmall
            color: Theme.soft
        }
        // and the collection's, under the folders
        SpecimenNote {
            x: stage.x + sheet.x + 6
            y: stage.y + stage.height + 14
            figure: "Fig. 1."
            name: "Collectio musicae"
            lines: [win.albums.length + (win.albums.length === 1 ? " folder" : " folders") + ", filed by album.",
                    (Gramophone.musicRoot !== "" ? Gramophone.musicRoot.replace(Settings.home, "~") : "~/Music") + "."]
        }

        Item {
            id: stage
            x: 44
            y: 74 + 18
            width: 1240
            height: 650

            // ------------------------------------------------------------ the folders' tabs
            Item {
                id: tabs
                x: 0
                y: 0
                width: 240
                height: sheet.height
                readonly property int perPage: 12
                readonly property int first: Math.max(0, Math.min(win.albums.length - perPage, win.folder - Math.floor(perPage / 2)))

                Repeater {
                    model: win.albums.length
                    Item {
                        id: tab
                        required property int index
                        readonly property int j: index - tabs.first
                        readonly property bool open: index === win.folder
                        visible: j >= 0 && j < tabs.perPage
                        x: open ? 0 : 14
                        y: 22 + j * 47
                        width: 236
                        height: 38
                        Behavior on x { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }

                        Paper {
                            anchors.fill: parent
                            seed: 2400 + tab.index
                            lift: tab.open ? 1.2 : 0.6
                            color: tab.open ? Theme.paperCard : Qt.darker(Theme.paperCard, 1.07)
                        }
                        Rectangle { visible: tab.open; x: 8; y: 8; width: 2; height: parent.height - 16; color: Theme.accent }
                        InkText {
                            x: 16
                            width: 160
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.albums[tab.index]?.name ?? ""
                            font.pixelSize: 13
                            color: tab.open ? Theme.graphite : Theme.soft
                            elide: Text.ElideRight
                        }
                        // a pencil tick: the one on the platter
                        InkText {
                            x: 180
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tab.index === Gramophone.albumIndex && win.ours
                            text: "✓"
                            color: Theme.madder
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { win.leafed = true; win.folder = tab.index; }
                        }
                    }
                }
                // more folders than tabs shown
                InkText {
                    visible: win.albums.length > tabs.perPage
                    x: 18
                    y: tabs.height - 26
                    text: String(win.folder + 1).padStart(2, "0") + " / " + String(win.albums.length).padStart(2, "0")
                    font.pixelSize: 12
                    color: Theme.faded
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => win.turn(wheel.angleDelta.y > 0 ? -1 : 1)
                }
            }

            // ------------------------------------------------------------ the open folder
            // (two folders' edges under it, so it reads as a stack)
            Paper { x: sheet.x + 5; y: sheet.y + 7; width: sheet.width; height: sheet.height; seed: 2500; lift: 0.5; color: Qt.darker(Theme.paperCard, 1.08); visible: win.albums.length > 1 }
            Paper { x: sheet.x + 2; y: sheet.y + 3; width: sheet.width; height: sheet.height; seed: 2501; lift: 0.5; color: Qt.darker(Theme.paperCard, 1.04); visible: win.albums.length > 0 }
            RecordSheet {
                id: sheet
                x: 196
                y: 10
                // another folder pulled from the stack and laid on top
                transform: Translate { id: shift }
                SequentialAnimation {
                    id: swap
                    ParallelAnimation {
                        NumberAnimation { target: shift; property: "y"; from: 0; to: 14; duration: Theme.dur(80); easing.type: Easing.InQuad }
                        NumberAnimation { target: sheet; property: "opacity"; to: 0.25; duration: Theme.dur(80) }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: shift; property: "y"; from: -22; to: 0; duration: Theme.dur(220); easing.type: Easing.OutBack }
                        NumberAnimation { target: shift; property: "x"; from: -10; to: 0; duration: Theme.dur(220); easing.type: Easing.OutCubic }
                        NumberAnimation { target: sheet; property: "opacity"; to: 1; duration: Theme.dur(140) }
                    }
                }
                album: win.album
                number: win.folder + 1
                count: win.albums.length
                selected: win.marked
                playing: win.ours && win.folder === Gramophone.albumIndex ? Gramophone.trackIndex : -1
                emptyWhere: Gramophone.musicRoot !== "" ? Gramophone.musicRoot.replace(Settings.home, "~") : "~/Music"
                reading: Gramophone.reading && !Gramophone.readOnce
                onPicked: t => { win.marked = t; win.playMarked(t); }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => win.mark(wheel.angleDelta.y > 0 ? -1 : 1)
                    z: -1
                }
            }

            // ------------------------------------------------------------ the gramophone
            Turntable {
                id: deck
                x: stage.width - width
                y: 40
                readonly property var onIt: win.ours ? Gramophone.album : null
                album: onIt
                labelTitle: win.ours ? (onIt?.name ?? Gramophone.track?.title ?? "") : (win.other ? (Media.album || Media.title) : "")
                labelArtist: win.ours ? (onIt?.artist ?? "") : (win.other ? Media.artist : "")
                labelNo: win.ours && Gramophone.albumIndex >= 0 ? "No. " + String(Gramophone.albumIndex + 1).padStart(3, "0") : ""
                nowPlaying: win.ours ? (Gramophone.track?.title ?? Gramophone.path.split("/").pop())
                           : (win.other ? Media.title + (Media.artist ? "  ·  " + Media.artist : "") : "")
                spinning: win.ours ? Gramophone.playing : (win.other && Media.playing)
                onRecord: win.ours || win.other
                lifted: win.ours ? Gramophone.paused : (win.other && !Media.playing)
                progress: win.ours ? Gramophone.albumProgress : Media.progress
                volume: Gramophone.volume
                volumeShown: win.ours

                onToggled: win.toggle()
                onWound: s => Gramophone.seek(s)
                onVolumeAsked: v => Gramophone.setVolume(v)
                onArmRested: { if (win.ours && !Gramophone.paused) Gramophone.toggle(); else if (win.other && Media.playing) Media.toggle(); }
                onNeedleDropped: f => {
                    if (win.ours) Gramophone.setNeedle(f);
                    else if (win.album) {
                        // nothing on: put the open folder's record on, from there
                        flight.start();
                        Gramophone.playAt(win.folder, f);
                    }
                }
            }

            // the figure is taped to the plate at its top corners
            Tape { x: deck.x - 22; y: deck.y + 8; width: 70; height: 19; rotation: -38; seed: 3131 }
            Tape { x: deck.x + deck.width - 48; y: deck.y + 8; width: 70; height: 19; rotation: 38; seed: 3132 }
            Tape { x: deck.x + deck.width - 50; y: deck.y + deck.height - 26; width: 70; height: 19; rotation: -36; seed: 3133 }

            // ------------------------------------------------------------ a record on its way
            // out of the folder and onto the platter
            Item {
                id: flyer
                visible: false
                width: 2 * deck.recordR
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: deck.vinyl
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 132; height: 132; radius: 66
                        color: Theme.paperRaised
                    }
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: 400 - index * 50; height: width; radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.05)
                        }
                    }
                }
                layer.enabled: true
                layer.effect: DropShadow { radius: 18; samples: 25; verticalOffset: 10; color: Qt.rgba(0, 0, 0, 0.45) }
            }
            SequentialAnimation {
                id: flight
                ScriptAction {
                    script: {
                        flyer.x = sheet.x + sheet.width / 2 - flyer.width / 2;
                        flyer.y = sheet.y + 168 - flyer.height / 2;
                        flyer.scale = 0.5;
                        flyer.rotation = 0;
                        flyer.opacity = 0;
                        flyer.visible = true;
                    }
                }
                // out of the sleeve: it slides up from behind the mount
                ParallelAnimation {
                    NumberAnimation { target: flyer; property: "opacity"; to: 1; duration: Theme.dur(140) }
                    NumberAnimation { target: flyer; property: "y"; to: sheet.y + 90 - flyer.height / 2; duration: Theme.dur(220); easing.type: Easing.OutCubic }
                }
                // and across, lifted over the desk, turning a little in the hand
                ParallelAnimation {
                    NumberAnimation { target: flyer; property: "scale"; to: 1.06; duration: Theme.dur(460); easing.type: Easing.OutCubic }
                    NumberAnimation { target: flyer; property: "rotation"; from: 0; to: 140; duration: Theme.dur(460); easing.type: Easing.InOutCubic }
                    NumberAnimation {
                        target: flyer; property: "x"
                        to: deck.x + deck.centre.x - flyer.width / 2
                        duration: Theme.dur(460); easing.type: Easing.InOutCubic
                    }
                    SequentialAnimation {
                        NumberAnimation { target: flyer; property: "y"; to: Math.min(sheet.y + 40, deck.y + deck.centre.y - 70) - flyer.height / 2; duration: Theme.dur(200); easing.type: Easing.OutQuad }
                        NumberAnimation { target: flyer; property: "y"; to: deck.y + deck.centre.y - flyer.height / 2; duration: Theme.dur(260); easing.type: Easing.InQuad }
                    }
                }
                // set down
                NumberAnimation { target: flyer; property: "scale"; to: 1.0; duration: Theme.dur(120); easing.type: Easing.InCubic }
                NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: Theme.dur(160) }
                ScriptAction { script: flyer.visible = false }
            }
        }
    }
}
