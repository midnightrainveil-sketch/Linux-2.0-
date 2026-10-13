import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The footer strip (section 10): bottom, full width, 40 px, paper.base with a
// 1.5 px rule on top and no card. Sprig glyph, workspaces, path breadcrumb,
// status marks, date.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    WlrLayershell.namespace: "archive-bar"
    color: Theme.paperBase

    Grain { anchors.fill: parent; strength: 1.15 }

    Rule {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: implicitHeight
        color: Theme.ruleInk
        drift: 0.35
        seed: 9001
    }

    // ---- left: sprig (opens the Card Catalogue) + workspaces
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin - 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24

        Item {
            width: 24
            height: Theme.barHeight
            InkIcon {
                anchors.centerIn: parent
                name: "sprig"
                size: 20
                color: sprigMouse.containsMouse || Panels.open === "catalogue" ? Theme.accent : Theme.soft
            }
            MouseArea {
                id: sprigMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("catalogue")
            }
        }

        Workspaces {}
    }

    // ---- centre: "/ home / atlas /"
    Row {
        anchors.centerIn: parent
        spacing: 0
        InkText {
            text: "/ "
            font.pixelSize: Theme.sizeBar
            color: Theme.faded
        }
        Repeater {
            model: Hypr.crumbs
            Row {
                required property string modelData
                InkText {
                    text: modelData
                    font.pixelSize: Theme.sizeBar
                    color: Theme.soft
                }
                InkText {
                    text: " / "
                    font.pixelSize: Theme.sizeBar
                    color: Theme.faded
                }
            }
        }
    }

    // ---- right: status + date
    Status {
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin - 8
        anchors.verticalCenter: parent.verticalCenter
    }
}
