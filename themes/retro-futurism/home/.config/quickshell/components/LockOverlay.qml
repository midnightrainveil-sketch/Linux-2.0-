import QtQuick
import QtQuick.Effects
import qs.services

// The lock screen's layer, flat on the picture, see-through. Up in the sky
// to the right, the time written in Japanese, top to bottom (二十一時 /
// 八分, the right column first), in a mincho; beside it, down a fine rule,
// the time, the day and the date in a quiet serif. Along the foot, in the
// same serif, how to get in and the machine's state. Drawn at 1920 px wide
// and scaled with the screen (s); the foot steps back while the pass is out.
//
//   LockOverlay { anchors.fill: parent; s: ...; now: tick.date; woken: 0 }
Item {
    id: hud

    property real s: 1
    property date now: new Date()
    property real woken: 0

    readonly property color cream: "#fff6ea"
    readonly property string serif: "Cormorant Garamond"
    readonly property string mincho: "Shippori Mincho"
    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July",
                                       "August", "September", "October", "November", "December"]

    // numbers as written in Japanese: 8 八, 21 二十一, 46 四十六
    function kanji(n: int): string {
        const d = "〇一二三四五六七八九";
        if (n < 10) return d.charAt(n);
        const t = Math.floor(n / 10), o = n % 10;
        return (t === 1 ? "" : d.charAt(t)) + "十" + (o === 0 ? "" : d.charAt(o));
    }
    readonly property string hourText: (now.getHours() === 0 ? "零" : kanji(now.getHours())) + "時"
    // (on the hour: 丁度, "exactly")
    readonly property string minuteText: now.getMinutes() === 0 ? "丁度" : kanji(now.getMinutes()) + "分"

    // a soft shade under the letters, so they read on the sky
    component Soft: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0.08, 0.05, 0.12, 0.55)
        shadowBlur: 1.0
        shadowVerticalOffset: 0
        shadowHorizontalOffset: 0
    }

    // ---- the clock
    Item {
        id: clock
        anchors.fill: parent
        layer.enabled: true
        layer.effect: Soft {}

        readonly property real size: 100 * hud.s                 // a character
        readonly property real step: 112 * hud.s                 // character to character
        readonly property real hourX: hud.width - 104 * hud.s    // the hour column's middle
        readonly property real top0: 92 * hud.s
        readonly property int rows: Math.max(hud.hourText.length, hud.minuteText.length)
        readonly property real foot: top0 + rows * step            // where both columns end

        component Column_: Repeater {
            id: col
            property string chars: ""
            property real cx: 0
            model: chars.length
            Text {
                required property int index
                x: col.cx - width / 2
                y: clock.foot - (col.chars.length - index) * clock.step
                width: clock.size * 1.1; height: clock.step
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: col.chars.charAt(index)
                color: hud.cream; opacity: 0.95
                font.family: hud.mincho; font.pixelSize: clock.size
            }
        }
        Column_ { chars: hud.hourText; cx: clock.hourX }
        Column_ { chars: hud.minuteText; cx: clock.hourX - clock.size * 1.42 }

        // the fine rule, and beside it the time in figures, the day, the date
        Rectangle {
            id: rule
            x: clock.hourX - clock.size * 2.3
            y: clock.top0 - 14 * hud.s
            width: Math.max(1, 1.2 * hud.s); height: clock.foot - y + 14 * hud.s
            color: hud.cream; opacity: 0.45
        }
        Column {
            anchors.right: rule.left; anchors.rightMargin: 22 * hud.s
            anchors.bottom: rule.bottom; anchors.bottomMargin: 8 * hud.s
            spacing: 0
            Text {
                anchors.right: parent.right
                text: Qt.formatTime(hud.now, "hh:mm")
                color: hud.cream; opacity: 0.9
                font.family: hud.serif; font.pixelSize: 40 * hud.s
            }
            Text {
                anchors.right: parent.right
                text: hud.dayNames[hud.now.getDay()]
                color: hud.cream; opacity: 0.78
                font.family: hud.serif; font.pixelSize: 28 * hud.s
            }
            Text {
                anchors.right: parent.right
                text: hud.now.getDate() + " " + hud.monthNames[hud.now.getMonth()]
                color: hud.cream; opacity: 0.78
                font.family: hud.serif; font.pixelSize: 28 * hud.s
            }
        }
    }

    // ---- along the foot: how to get in, and the machine, in the same serif
    Item {
        id: foot
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom; anchors.bottomMargin: 44 * hud.s
        height: 70 * hud.s
        opacity: 1 - hud.woken
        visible: opacity > 0.01
        layer.enabled: visible
        layer.effect: Soft {}

        Row {
            id: invite
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 22 * hud.s
            component Hair: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 70 * hud.s; height: Math.max(1, hud.s); color: hud.cream; opacity: 0.5
            }
            Hair {}
            Text {
                text: "press any key to unlock"
                color: hud.cream
                font.family: hud.serif; font.italic: true; font.pixelSize: 30 * hud.s
                SequentialAnimation on opacity {
                    running: foot.visible; loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 2200; easing.type: Easing.InOutSine }
                }
            }
            Hair {}
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: invite.bottom; anchors.topMargin: 4 * hud.s
            text: {
                const parts = [];
                if (Media.active) parts.push(Media.title + (Media.artist !== "" ? ", " + Media.artist : ""));
                if (Notifs.count > 0) parts.push(Notifs.count + (Notifs.count === 1 ? " notification" : " notifications"));
                if (Net.wired) parts.push("wired");
                else if (Net.ssid !== "") parts.push(Net.ssid);
                if (Power.present) parts.push(Power.percent + "%" + (Power.charging ? " charging" : ""));
                return parts.join("   ·   ");
            }
            color: hud.cream; opacity: 0.72
            font.family: hud.serif; font.pixelSize: 21 * hud.s; font.letterSpacing: 1 * hud.s
        }
    }
}
