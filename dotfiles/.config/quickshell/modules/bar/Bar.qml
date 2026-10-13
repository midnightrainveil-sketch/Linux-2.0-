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
        weight: 1.7
        drift: 0.45
        seed: 9001
    }

    // ---- left: seedling (opens the Card Catalogue) + workspaces
    Item {
        x: 19
        width: 28
        height: Theme.barHeight
        InkIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            name: "seedling"
            size: 28
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

    Workspaces {
        x: 75
        anchors.verticalCenter: parent.verticalCenter
    }

    // ---- centre: "/ home / atlas /"
    Row {
        anchors.centerIn: parent
        spacing: 0
        InkText {
            text: "/ "
            font.pixelSize: Theme.sizeSmall
            color: Theme.soft
        }
        Repeater {
            model: Hypr.crumbs
            Row {
                required property string modelData
                InkText {
                    text: modelData
                    font.pixelSize: Theme.sizeSmall
                    color: Theme.soft
                }
                InkText {
                    text: " / "
                    font.pixelSize: Theme.sizeSmall
                    color: Theme.soft
                }
            }
        }
    }

    // ---- right: status + date
    Status {
        anchors.right: parent.right
        anchors.rightMargin: 23
        anchors.verticalCenter: parent.verticalCenter
    }
}
