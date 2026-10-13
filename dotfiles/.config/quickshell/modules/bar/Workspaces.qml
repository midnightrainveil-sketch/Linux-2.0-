import QtQuick
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components

// Workspaces as typed numbers. Occupied: ink.soft. Empty: ink.faded.
// Active: underlined with a short 2 px rule, as on the reference. Urgent: a small stamp mark.
Row {
    id: root
    spacing: 0

    readonly property var ids: {
        let top = Settings.minWorkspaces;
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.id <= 9) top = Math.max(top, w.id);
        const out = [];
        for (let i = 1; i <= top; i++) out.push(i);
        return out;
    }
    readonly property int activeId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    function workspace(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    Repeater {
        model: root.ids

        Item {
            id: cell
            required property int modelData
            readonly property var ws: root.workspace(modelData)
            readonly property bool active: root.activeId === modelData
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0
            readonly property bool urgent: ws?.urgent ?? false

            width: 50
            height: Theme.barHeight

            InkText {
                id: num
                anchors.centerIn: parent
                text: String(cell.modelData)
                font.pixelSize: 17
                color: cell.active ? Theme.graphite : cell.occupied ? Theme.soft : Theme.labelInk
                Behavior on color { ColorAnimation { duration: Theme.durFocus } }
            }

            Rectangle {
                anchors.horizontalCenter: num.horizontalCenter
                anchors.top: num.bottom
                anchors.topMargin: 1
                height: 2
                width: cell.active ? 20 : 0
                color: Theme.soft
                Behavior on width { NumberAnimation { duration: Theme.durFocus; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place } }
            }

            // urgent: a tiny ring stamp pressed beside the number
            Canvas {
                visible: cell.urgent
                width: 9; height: 9
                anchors.left: num.right
                anchors.bottom: num.top
                anchors.bottomMargin: -4
                rotation: -8
                property color c: Theme.accent
                onCChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = c;
                    ctx.lineWidth = 1.2;
                    ctx.beginPath(); ctx.ellipse(0.8, 0.8, width - 1.6, height - 1.6); ctx.stroke();
                    ctx.lineWidth = 0.7;
                    ctx.beginPath(); ctx.ellipse(2.6, 2.6, width - 5.2, height - 5.2); ctx.stroke();
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.workspace(cell.modelData)
            }
        }
    }

    WheelHandler {
        onWheel: e => Hypr.relativeWorkspace(e.angleDelta.y > 0 ? -1 : 1)
    }
}
