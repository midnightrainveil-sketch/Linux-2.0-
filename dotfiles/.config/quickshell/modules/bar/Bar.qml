import QtQuick
import Quickshell
import Quickshell.Hyprland
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

    // a touch lighter in Folio, where the cards beside it carry more
    Grain { anchors.fill: parent; strength: Theme.fv(1.15, 1.0) }

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
        id: workspaces
        x: 75
        anchors.verticalCenter: parent.verticalCenter
    }

    // the desk button: a small index card. Lays the record cards and the
    // desk terminal back out as at login (archive-desk, also Super+D).
    Item {
        id: deskButton
        x: workspaces.x + workspaces.width + 22
        width: 30
        height: Theme.barHeight
        readonly property color ink: deskMouse.containsMouse ? Theme.accent : Theme.soft

        Rectangle {
            anchors.centerIn: parent
            width: 20
            height: 14
            color: "transparent"
            border.width: 1.4
            border.color: deskButton.ink
            radius: 1
            // the card's header rule and a line of type
            Rectangle { x: 3; y: 4; width: parent.width - 6; height: 1.2; color: deskButton.ink }
            Rectangle { x: 3; y: 8; width: (parent.width - 6) * 0.6; height: 1.2; color: deskButton.ink; opacity: 0.7 }
        }
        MouseArea {
            id: deskMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["archive-desk"])
        }
    }

    // the Register button: two cards in a stack and how many windows are
    // open; opens the Register (also Super+W, Alt+Tab)
    Item {
        id: registerButton
        // on the same beat as the workspace numbers and the desk button: its
        // card stack (centred 12 px in) as far past the desk button's centre
        // as that is past the last number's (cells are 50 wide)
        readonly property real beat: (deskButton.x + deskButton.width / 2) - (workspaces.x + workspaces.width - 25)
        x: deskButton.x + deskButton.width / 2 + beat - 12
        width: 26 + countText.implicitWidth
        height: Theme.barHeight
        readonly property color ink: registerMouse.containsMouse || Panels.open === "register" ? Theme.accent : Theme.soft
        readonly property int count: Hyprland.toplevels.values.length

        Rectangle {
            x: 6; y: parent.height / 2 - 4
            width: 16; height: 11
            color: "transparent"
            border.width: 1.2
            border.color: registerButton.ink
            radius: 1
            opacity: 0.6
        }
        Rectangle {
            x: 2; y: parent.height / 2 - 7
            width: 16; height: 11
            color: Theme.paperBase
            border.width: 1.4
            border.color: registerButton.ink
            radius: 1
            Rectangle { x: 3; y: 3.5; width: parent.width - 6; height: 1.2; color: registerButton.ink }
        }
        InkText {
            id: countText
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: registerButton.count
            font.pixelSize: Theme.sizeSmall
            color: registerButton.ink
        }
        MouseArea {
            id: registerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "shell", "register"])
        }
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
