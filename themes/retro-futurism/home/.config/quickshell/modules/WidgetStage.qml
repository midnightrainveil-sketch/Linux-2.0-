import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The stage the widgets come up on: over everything on the screen in use,
// what lies behind blurred (Hyprland blurs this layer, see rules.lua) and
// dimmed, the widget in the middle with the keyboard. Esc or a click
// outside the widget puts it away.
//
// It loads the widget's file when called and unloads it when gone, so a
// widget costs nothing while put away.
PanelWindow {
    id: stage

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-stage"
    WlrLayershell.keyboardFocus: up ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: Widgets.current !== "" || leaving.running

    readonly property bool up: Widgets.current !== ""
    property string loaded: ""              // what the loader holds (kept while it leaves)

    // 0: away, 1: up
    property real p: 0
    NumberAnimation on p { id: coming; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 0.9; running: false }
    NumberAnimation on p { id: leaving; to: 0; duration: 200; easing.type: Easing.InCubic; running: false
        onFinished: if (!stage.up) stage.loaded = "" }

    Connections {
        target: Widgets
        function onCurrentChanged() {
            if (Widgets.current !== "") {
                leaving.stop();
                if (stage.loaded !== Widgets.current) { stage.loaded = Widgets.current; stage.p = 0; }
                coming.restart();
            } else {
                if (loader.item) { loader.item.shown = false; loader.item.closing(); }
                coming.stop();
                leaving.restart();
            }
        }
    }

    // ---- what lies behind: dimmed (and blurred by Hyprland)
    Rectangle {
        anchors.fill: parent
        color: "#140f0b"
        opacity: 0.38 * Math.min(1, stage.p)
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Widgets.close()
    }

    // ---- the widget: rises a little and grows into place
    Item {
        id: holder
        readonly property real fit: loader.item
            ? Math.min(1, (stage.width * 0.9) / loader.item.preferredWidth,
                          (stage.height * 0.88) / loader.item.preferredHeight,
                          stage.width / 1920)
            : 1
        width: loader.item ? loader.item.preferredWidth : 0
        height: loader.item ? loader.item.preferredHeight : 0
        x: (stage.width - width) / 2
        y: (stage.height - height) / 2 + (1 - stage.p) * 40
        scale: fit * (0.94 + 0.06 * stage.p)
        opacity: Math.min(1, stage.p * 1.4)

        // clicks on the widget stay with it
        MouseArea { anchors.fill: parent; onClicked: {} }

        Loader {
            id: loader
            anchors.fill: parent
            source: stage.loaded !== "" ? Widgets.source(stage.loaded) : ""
            focus: true
            onLoaded: {
                item.focus = true;
                item.forceActiveFocus();
            }
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
