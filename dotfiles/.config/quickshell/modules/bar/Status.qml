import QtQuick
import qs.theme
import qs.services
import qs.components

// Right side of the footer strip: margin-sketch status marks and the date.
// Marks open the Instrument card; the date opens the Ledger.
Row {
    id: root
    spacing: 14

    // a mark that darkens on hover
    component Mark: Item {
        id: mark
        property string icon: ""
        property color ink: hover.containsMouse ? Theme.graphite : Theme.soft
        property alias hovered: hover.containsMouse
        signal clicked()
        width: 20
        height: Theme.barHeight
        InkIcon {
            anchors.centerIn: parent
            name: mark.icon
            size: 18
            color: mark.ink
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mark.clicked()
        }
    }

    // Day / night: the screen mark. Click to turn the plate over.
    Mark {
        icon: Theme.night > 0.5 ? "screen-night" : "screen"
        onClicked: Mode.toggle()
    }

    Mark {
        icon: Audio.muted ? "speaker-muted" : (Audio.volume > 0.5 ? "speaker-loud" : "speaker")
        onClicked: Panels.toggle("instrument")
        WheelHandler { onWheel: e => Audio.setVolume(Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
    }

    Mark {
        icon: !Net.wifiOn ? "wifi-off" : (Net.online ? "wifi" : "wifi-none")
        ink: !Net.online ? Theme.faded : (hovered ? Theme.graphite : Theme.soft)
        onClicked: Panels.toggle("instrument")
    }

    // battery: outline in ink, filled level in accent (madder when low)
    Item {
        visible: Power.present
        width: battery.width + 6 + pct.implicitWidth
        height: Theme.barHeight

        Canvas {
            id: battery
            width: 22; height: 12
            anchors.verticalCenter: parent.verticalCenter
            property color outline: Theme.soft
            property color fill: Power.low ? Theme.madder : Theme.accent
            property real level: Power.percent / 100
            property bool charging: Power.charging
            onOutlineChanged: requestPaint()
            onFillChanged: requestPaint()
            onLevelChanged: requestPaint()
            onChargingChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = outline;
                ctx.lineWidth = 1.3;
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(1.2, 1.4); ctx.lineTo(18.6, 1.1); ctx.lineTo(18.8, 10.7); ctx.lineTo(1.0, 10.9); ctx.closePath();
                ctx.stroke();
                ctx.fillStyle = outline;
                ctx.fillRect(19.6, 4, 1.8, 4.2);
                ctx.fillStyle = fill;
                ctx.fillRect(3, 3.2, Math.max(0.8, 14 * level), 5.8);
                if (charging) {
                    ctx.strokeStyle = Theme.paperBase;
                    ctx.lineWidth = 1.4;
                    ctx.beginPath(); ctx.moveTo(11, 2.2); ctx.lineTo(8, 6.2); ctx.lineTo(11.5, 6); ctx.lineTo(8.6, 10); ctx.stroke();
                }
            }
        }
        InkText {
            id: pct
            anchors.left: battery.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Power.percent + "%"
            font.pixelSize: Theme.sizeBar
            color: Power.low ? Theme.madder : Theme.soft
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("instrument")
        }
    }

    Item {
        width: date.implicitWidth + 8
        height: Theme.barHeight
        InkText {
            id: date
            anchors.centerIn: parent
            text: Clock.barDate
            font.pixelSize: Theme.sizeBar
            color: dateMouse.containsMouse || Panels.open === "ledger" ? Theme.graphite : Theme.soft
        }
        MouseArea {
            id: dateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("ledger")
        }
    }
}
