import QtQuick
import qs.theme
import qs.services
import qs.components

// Now playing: whatever player is running (MPRIS).
Box {
    id: card
    title: "Now playing"
    height: 206

    // five bars at the right of the heading, moving while it plays (one
    // timer for all five; still under a fullscreen window)
    property var levels: [0.3, 0.75, 1, 0.55, 0.25]
    Timer {
        interval: 420
        running: Media.playing && !Hypr.fullscreen
        repeat: true
        onTriggered: card.levels = card.levels.map(() => 0.2 + Math.random() * 0.8)
        onRunningChanged: if (!running) card.levels = [0.3, 0.75, 1, 0.55, 0.25]
    }
    Row {
        parent: card.header
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 3
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 2
                height: Math.max(2, Math.round(14 * card.levels[index]))
                anchors.bottom: parent.bottom
                color: Theme.ink
            }
        }
    }

    Rectangle {
        id: cover
        x: 14; y: 12
        width: 92; height: 92
        color: "#151415"
        Image {
            anchors.fill: parent
            source: Media.art !== "" ? Media.art : Settings.art + "/frame-2.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 184
            sourceSize.height: 184
        }
    }
    Label {
        x: 124; y: 14
        width: card.width - x - 16
        text: Media.active ? Media.title : "Nothing playing"
        font.pixelSize: 17
        tracking: 1.4
    }
    Label {
        x: 124; y: 40
        width: card.width - x - 16
        text: Media.active ? Media.artist : "Start a player"
        font.pixelSize: 13
        color: Theme.dim
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 66
        visible: Media.active && Media.length > 0
        text: Media.time(Media.position) + " / " + Media.time(Media.length)
        font.pixelSize: 12
        tracking: 0.8
    }
    Item {
        x: 124; y: 90
        width: card.width - x - 16
        height: 10
        Rectangle { y: 4; width: parent.width; height: 2; color: Theme.faint }
        Rectangle { y: 3; width: Math.round(parent.width * Media.progress); height: 4; color: Theme.ink }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: e => Media.seekTo(Media.length * Math.max(0, Math.min(1, (e.x - 5) / parent.width)))
        }
    }

    Row {
        x: 14
        y: 122
        width: card.width - 28
        Repeater {
            model: ["shuffle", "prev", Media.playing ? "pause" : "play", "next", "repeat"]
            Item {
                id: key
                required property string modelData
                required property int index
                width: parent.width / 5
                height: 34
                readonly property bool lit: (index === 0 && Media.shuffle) || (index === 4 && Media.looping)
                Icon {
                    anchors.centerIn: parent
                    name: key.modelData
                    size: key.index === 2 ? 26 : 22
                    color: key.lit ? Theme.accent : Theme.ink
                    opacity: keyMouse.containsMouse ? 1 : 0.92
                }
                MouseArea {
                    id: keyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (key.index === 0) Media.toggleShuffle();
                        else if (key.index === 1) Media.previous();
                        else if (key.index === 2) Media.toggle();
                        else if (key.index === 3) Media.next();
                        else Media.toggleLoop();
                    }
                }
            }
        }
    }
}
