import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// Right side of the footer strip: margin-sketch status marks and the date.
// Marks open the Instrument card; the date opens the Ledger.
Row {
    id: root
    spacing: 22

    // a figure and its unit, set close as a typesetter would ("120 Hz" in a
    // typewriter face otherwise has a whole letter's gap)
    component Measure: Row {
        id: measure
        property string figure: ""
        property string unit: ""
        property color ink: Theme.soft
        property color unitInk: ink
        spacing: 2
        InkText { text: measure.figure; font.pixelSize: Theme.sizeSmall; color: measure.ink }
        InkText { text: measure.unit; font.pixelSize: Theme.sizeSmall; color: measure.unitInk }
    }

    // a mark that darkens on hover
    component Mark: Item {
        id: mark
        property string icon: ""
        property color ink: hover.containsMouse ? Theme.graphite : Theme.soft
        property alias hovered: hover.containsMouse
        // the glyphs sit differently in their squares: a nudge on the left
        // so the marks stand evenly apart by their ink, not by their boxes
        property real lead: 0
        signal clicked()
        width: 20 + lead
        height: Theme.barHeight
        InkIcon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: mark.lead / 2
            name: mark.icon
            size: 20
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

    // The panel's refresh rate, typed: click for 60 / 120 Hz; Auto (set in
    // Instruments) shows the rate it is at now (archive-refresh)
    Item {
        width: hz.implicitWidth
        height: Theme.barHeight
        Measure {
            id: hz
            anchors.centerIn: parent
            figure: String(Refresh.rate)
            unit: "Hz"
            ink: hzMouse.containsMouse ? Theme.graphite : Theme.soft
        }
        MouseArea {
            id: hzMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Refresh.toggle()
        }
    }

    Mark {
        icon: Audio.muted ? "speaker-muted" : (Audio.volume > 0.5 ? "speaker-loud" : "speaker")
        lead: -1
        onClicked: Panels.toggle("instrument")
        WheelHandler { onWheel: e => Audio.setVolume(Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
    }

    Mark {
        icon: !Net.wifiOn ? "wifi-off" : (Net.online ? "wifi" : "wifi-none")
        lead: -2
        ink: !Net.online ? Theme.faded : (hovered ? Theme.graphite : Theme.soft)
        onClicked: Panels.toggle("instrument")
    }

    // battery: outline in ink, filled level in accent (madder when low)
    Item {
        visible: Power.present
        width: 2 + battery.width + 6 + pct.implicitWidth + (rate.visible ? 8 + rate.implicitWidth : 0)
        height: Theme.barHeight

        Canvas {
            id: battery
            x: 2
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
            font.pixelSize: Theme.sizeSmall
            color: Power.low ? Theme.madder : Theme.soft
        }
        // the rate it fills or drains at: "+38 W", "−9.6 W"
        Measure {
            id: rate
            visible: Power.rateWord !== ""
            anchors.left: pct.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            figure: Power.rateWord.replace(/\s*W$/, "")
            unit: "W"
            ink: Theme.faded
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("instrument")
        }
    }

    Item {
        width: date.implicitWidth + 2
        height: Theme.barHeight
        InkText {
            id: date
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.barDate
            font.pixelSize: Theme.sizeSmall
            color: dateMouse.containsMouse || Panels.open.startsWith("ledger") ? Theme.graphite : Theme.soft
        }
        MouseArea {
            id: dateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.open.startsWith("ledger") ? Panels.close() : Panels.show("ledger")
        }
    }
}
