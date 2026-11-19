import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// Where the widgets come up. The shell has two of these:
//
//   WidgetStage {}                  "center": the widget in the middle, what
//                                   lies behind blurred (Hyprland blurs this
//                                   layer, rules.lua) and dimmed
//   WidgetStage { taskbar: true }   "taskbar": the widget over the taskbar's
//                                   right end, its right edge on the bar's,
//                                   over the windows, nothing blurred
//
// Each shows only the widgets of its placement (widgets/index.json). The
// widget has the keyboard while up; Esc or a click outside puts it away. Its
// file is loaded when called and unloaded when gone.
PanelWindow {
    id: stage

    property bool taskbar: false
    readonly property string kind: taskbar ? "taskbar" : "center"

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: taskbar ? "retro-futurism-popover" : "retro-futurism-stage"
    WlrLayershell.keyboardFocus: up ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: up || leaving.running

    readonly property bool up: Widgets.current !== "" && Widgets.placement(Widgets.current) === kind
    property string loaded: ""              // what the loader holds (kept while it leaves)

    // 0: away, 1: up
    property real p: 0
    NumberAnimation on p {
        id: coming; to: 1; running: false
        duration: stage.taskbar ? 230 : 340
        easing.type: stage.taskbar ? Easing.OutCubic : Easing.OutBack
        easing.overshoot: 0.9
    }
    NumberAnimation on p {
        id: leaving; to: 0; running: false
        duration: stage.taskbar ? 160 : 200
        easing.type: Easing.InCubic
        onFinished: if (!stage.up) stage.loaded = ""
    }

    onUpChanged: {
        if (up) {
            // called again while it was going: a fresh one, not the one leaving
            if (leaving.running) { leaving.stop(); loaded = ""; }
            if (loaded !== Widgets.current) { loaded = Widgets.current; p = 0; }
            coming.restart();
        } else if (loaded !== "") {
            if (loader.item) { loader.item.shown = false; loader.item.closing(); }
            coming.stop();
            leaving.restart();
        }
    }
    // one widget of this placement swapped for another while up
    Connections {
        target: Widgets
        function onCurrentChanged() {
            if (stage.up && stage.loaded !== Widgets.current) {
                stage.loaded = Widgets.current; stage.p = 0; coming.restart();
            }
        }
    }

    // ---- what lies behind: dimmed and blurred in the middle; untouched over the taskbar
    Rectangle {
        anchors.fill: parent
        visible: !stage.taskbar
        color: "#140f0b"
        opacity: 0.38 * Math.min(1, stage.p)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Widgets.close()
    }

    // ---- the widget
    Item {
        id: holder
        readonly property real fit: !loader.item || stage.taskbar ? 1
            : Math.min(1, (stage.width * 0.9) / loader.item.preferredWidth,
                          (stage.height * 0.88) / loader.item.preferredHeight,
                          stage.width / 1920)
        width: loader.item ? loader.item.preferredWidth : 0
        height: loader.item ? loader.item.preferredHeight : 0
        // in the middle; or its right edge on the taskbar's, just over its tube
        readonly property real airR: loader.item ? loader.item.airRight : 0
        readonly property real airB: loader.item ? loader.item.airBottom : 0
        // (over the taskbar: set in from the bar's end, within its line and the frames')
        x: stage.taskbar ? stage.width - Theme.frameMargin - 18 - width + airR : (stage.width - width) / 2
        y: (stage.taskbar ? stage.height - Theme.taskbarReach - 12 - height + airB : (stage.height - height) / 2)
           + (1 - stage.p) * (stage.taskbar ? 26 : 40)
        transformOrigin: stage.taskbar ? Item.BottomRight : Item.Center
        scale: fit * (stage.taskbar ? 0.97 + 0.03 * stage.p : 0.94 + 0.06 * stage.p)
        opacity: Math.min(1, stage.p * 1.4)

        // clicks on the widget stay with it
        MouseArea { anchors.fill: parent; onClicked: {} }

        Loader {
            id: loader
            anchors.fill: parent
            source: stage.loaded !== "" ? Widgets.source(stage.loaded) : ""
            focus: true
            onLoaded: item.forceActiveFocus()
            onStatusChanged: if (status === Loader.Error) console.warn("widgets: could not load", stage.loaded)
        }
    }

    // once up: tell the widget, and give it the keyboard
    Connections {
        target: coming
        function onFinished() {
            if (!loader.item) return;
            loader.item.shown = true;
            loader.item.forceActiveFocus();
            loader.item.opened();
        }
    }
}
