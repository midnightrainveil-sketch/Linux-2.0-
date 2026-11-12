import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// What lies behind the windows: the picture, the viewfinder's marks, the
// right-hand column (now playing, notes), and for each window in view a
// caption under it, with focus marks round the one in use.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "viewfinder-backdrop"
    color: "#0b0a0b"

    Image {
        anchors.fill: parent
        source: Settings.wallpaper !== "" ? Settings.wallpaper : Settings.art + "/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: false
        cache: false
    }

    // ---- the frame lines
    Corners {
        x: 27; y: Theme.barTop + 27
        width: win.width - 54
        height: win.height - Theme.barTop - Theme.barBottom - 54
        arm: 34; weight: 3
    }

    // ---- the focusing mark, where no window lies over it
    Item {
        id: focusMark
        width: 132; height: 108
        x: Math.round((win.width - width) / 2)
        y: Math.round((win.height - height) / 2)
        visible: !Hypr.windows.some(w => w.x < x + width && w.x + w.w > x && w.y < y + height && w.y + w.h > y)
        Corners { anchors.fill: parent; arm: 26; weight: 3 }
        Rectangle { anchors.centerIn: parent; width: 20; height: 2; color: Theme.ink }
        Rectangle { anchors.centerIn: parent; width: 2; height: 20; color: Theme.ink }
    }

    // ---- the right-hand column
    Column {
        id: column
        x: win.width - Theme.edge - Theme.columnWidth
        y: Theme.barTop + 108
        width: Theme.columnWidth
        spacing: 26
        NowPlaying { width: parent.width }
        NotesCard { width: parent.width }
        // (where notifications are shown: Mail.qml, over the windows)
        onHeightChanged: Panels.mailY = y + height + spacing
        Component.onCompleted: Panels.mailY = y + height + spacing
    }

    // ---- captions and focus marks
    Item {
        anchors.fill: parent
        visible: !Hypr.fullscreen
        Repeater {
            model: Hypr.windows
            Item {
                id: mark
                required property var modelData
                required property int index
                x: modelData.x; y: modelData.y
                width: modelData.w; height: modelData.h
                Label {
                    x: 8
                    y: parent.height + 8
                    width: parent.width - 16
                    font.pixelSize: 15
                    tracking: 1.4
                    color: mark.modelData.active ? Theme.ink : Theme.dim
                    text: "#" + Hypr.activeId + (mark.index + 1) + "   " + Apps.label(mark.modelData.cls)
                }
                Corners {
                    visible: mark.modelData.active && Hypr.windows.length > 1
                    x: -7; y: -7
                    width: parent.width + 14; height: parent.height + 14
                    arm: 16; weight: 2
                    color: Theme.accent
                }
            }
        }
    }
}
