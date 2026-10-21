import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

// A page of the herbarium turned as the workspace changes: the edge of a
// page sweeps across the sheet in the direction of travel (to a later
// workspace: right to left), its shadow cast ahead of it, broadest while
// the page is highest, and the light caught on its curl behind it. The
// sheet stays; the windows slide with the page (look.lua's "page" curve).
// Over everything, for half a second, and nothing to click; not as the
// shell starts, nor with reduced motion. After a three-finger swipe it
// plays as the fingers let go: Hyprland says nothing until then.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-page"
    visible: sweep.running

    readonly property int activeId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    property int lastId: activeId
    property bool settled: false
    property int dir: 1                 // 1: to a later page, -1: back
    property real p: 0                  // how far the page has turned, 0 to 1

    Timer { running: true; interval: 3000; onTriggered: win.settled = true }

    onActiveIdChanged: {
        const from = lastId;
        lastId = activeId;
        if (!settled || Theme.reducedMotion || activeId < 1 || from < 1) return;
        if (Hyprland.focusedMonitor?.name !== modelData.name) return;
        dir = activeId > from ? 1 : -1;
        sweep.restart();
    }

    NumberAnimation {
        id: sweep
        target: win
        property: "p"
        from: 0
        to: 1
        duration: 480
        // the page curve (look.lua): it lifts slowly, sweeps, lays down
        easing.type: Easing.Bezier
        easing.bezierCurve: [0.7, 0, 0.2, 1, 1, 1]
    }

    readonly property real lift: Math.sin(Math.PI * p)     // highest mid-turn
    readonly property real shadowW: width * (0.06 + 0.2 * lift)
    readonly property real curlW: 70 + 60 * lift

    // the edge, drawn for a page going right to left and mirrored for back;
    // tilted a little, the page's lower corner leading
    Item {
        id: edge
        width: 1
        height: win.height * 1.4
        y: -win.height * 0.2
        x: win.dir > 0 ? win.width + win.shadowW - (win.width + win.shadowW + win.curlW) * win.p
                       : -win.shadowW + (win.width + win.shadowW + win.curlW) * win.p
        rotation: -6 * win.dir
        transform: Scale { xScale: win.dir; origin.x: 0 }

        // the shadow it casts ahead, deepest at the edge
        Rectangle {
            x: -win.shadowW
            width: win.shadowW
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.75; color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.06 + 0.05 * win.lift) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.13 + 0.09 * win.lift) }
            }
        }
        // the light on its curl, behind the edge
        Rectangle {
            width: win.curlW
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.99, 0.96, 0.30 - 0.16 * Theme.night) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 0.99, 0.96, 0.12 - 0.06 * Theme.night) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        // the cut edge of the page itself
        Rectangle {
            x: -1
            width: 1.5
            height: parent.height
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.28)
        }
    }
}
