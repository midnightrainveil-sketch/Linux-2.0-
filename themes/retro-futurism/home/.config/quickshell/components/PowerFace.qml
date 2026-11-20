import QtQuick

// The Kairo device's power face (art/Power.png): SYSTEM CONTROL, the
// choices, a mark either side of the one chosen, what is chosen and how to
// do it. The power widget shows it, and the lock screen (◀◀ / ▶▶ turn the
// device from its pass to this and back). Drawn in the mock-up's pixels:
// put it inside a PassDevice (it glows with the rest of the face).
//
//   options    [{ word, doing, icon }]: icon one of lock, moon, exit, again, power
//   sel        the one chosen; going: on its way; note: said a moment instead
//   chose(i)   a line clicked; confirmed(): the chosen one clicked
Item {
    id: face

    required property var dev                  // the PassDevice it is on
    property var options: []
    property int sel: 0
    property bool going: false
    property string note: ""
    property string hint: "ENTER TO CONFIRM"
    // each line's middle, in the mock-up
    readonly property var rowY: [450, 557, 662, 767, 874]
    signal chose(int i)
    signal confirmed()

    width: 1162; height: 1201

    component Glow: Text {
        color: "#f2f8ff"
        font.family: "Barlow"
        font.weight: Font.Medium
    }
    component Rule: Rectangle { height: 3; color: "#f2f8ff"; opacity: 0.92 }
    component Slashes: Repeater {
        id: sl
        property real x0: 0
        property real y0: 0
        property real h: 16
        model: 3
        Rectangle {
            required property int index
            x: sl.x0 + index * sl.h * 1.45; y: sl.y0; width: sl.h * 0.6; height: sl.h; color: "#f2f8ff"
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.6, 0, sl.h * 0.6, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
        }
    }

    // ---- an icon, drawn: lock, moon, exit, again, power
    component Icon: Canvas {
        id: ic
        property string name: ""
        property real stroke: 6
        width: 56; height: 56
        onNameChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            c.strokeStyle = "#f2f8ff"; c.fillStyle = "#f2f8ff";
            c.lineWidth = ic.stroke; c.lineCap = "round"; c.lineJoin = "round";
            switch (ic.name) {
            case "lock":
                c.beginPath(); c.arc(28, 22, 11, Math.PI, 0); c.lineTo(39, 27); c.moveTo(17, 27); c.lineTo(17, 22); c.stroke();
                c.fillRect(10, 26, 36, 27);
                c.globalCompositeOperation = "destination-out";
                c.beginPath(); c.arc(28, 36, 4.5, 0, Math.PI * 2); c.fill(); c.fillRect(26, 37, 4, 9);
                break;
            case "moon":
                c.beginPath(); c.arc(28, 28, 22, 0, Math.PI * 2); c.fill();
                c.globalCompositeOperation = "destination-out";
                c.beginPath(); c.arc(40, 18, 20, 0, Math.PI * 2); c.fill();
                break;
            case "exit":
                c.beginPath(); c.moveTo(30, 8); c.lineTo(48, 8); c.lineTo(48, 48); c.lineTo(30, 48); c.stroke();
                c.beginPath(); c.moveTo(6, 28); c.lineTo(34, 28); c.moveTo(24, 18); c.lineTo(34, 28); c.lineTo(24, 38); c.stroke();
                break;
            case "again":
                c.beginPath(); c.arc(28, 28, 18, Math.PI * 1.1, Math.PI * 1.85); c.stroke();
                c.beginPath(); c.arc(28, 28, 18, Math.PI * 0.1, Math.PI * 0.85); c.stroke();
                c.beginPath(); c.moveTo(44, 6); c.lineTo(45, 18); c.lineTo(33, 17); c.stroke();
                c.beginPath(); c.moveTo(12, 50); c.lineTo(11, 38); c.lineTo(23, 39); c.stroke();
                break;
            case "power":
                c.beginPath(); c.arc(28, 30, 19, -Math.PI * 0.32, Math.PI * 1.32); c.stroke();
                c.beginPath(); c.moveTo(28, 6); c.lineTo(28, 28); c.stroke();
                break;
            }
        }
    }

    // ---- header: ⏻ | ///, SYSTEM CONTROL, POWER MANAGEMENT
    Icon { x: face.dev.ax(203); y: face.dev.ay(179); name: "power"; stroke: 4.6 }
    Rectangle { x: face.dev.ax(298); y: face.dev.ay(188); width: 3; height: 39; color: face.dev.ink }
    Slashes { x0: face.dev.ax(333); y0: face.dev.ay(197); h: 19 }
    Glow { x: face.dev.ax(191); y: face.dev.ay(250); text: "SYSTEM CONTROL"; font.pixelSize: 56; font.weight: Font.DemiBold; font.letterSpacing: 7.6 }
    Glow { x: face.dev.ax(192); y: face.dev.ay(318); text: "POWER MANAGEMENT"; font.pixelSize: 26; font.letterSpacing: 13.4 }
    Rule { x: face.dev.ax(191); y: face.dev.ay(373); width: 501 }
    Slashes { x0: face.dev.ax(708); y0: face.dev.ay(362); h: 16 }

    // ---- the five lines
    Repeater {
        model: face.options
        Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool chosen: index === face.sel
            x: face.dev.ax(207); y: face.dev.ay(face.rowY[index] - 53)
            width: 487; height: 106
            opacity: chosen ? 1 : 0.78
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Icon {
                x: 270 - 207 - 28; y: 53 - 28
                name: line.modelData.icon
            }
            Glow {
                x: 350 - 207; y: 53 - height / 2
                text: line.modelData.word
                font.pixelSize: 44
                font.weight: line.chosen ? Font.Bold : Font.DemiBold
                font.letterSpacing: 7
            }
            Rule { x: 0; y: 53 + 52; width: 487; opacity: 0.85 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: line.chosen ? face.confirmed() : face.chose(line.index)
            }
        }
    }
    // the marks either side of the chosen line, gliding with it
    Item {
        id: marks
        x: 0; y: face.dev.ay(face.rowY[face.sel])
        Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Canvas {
            x: face.dev.ax(193); y: -10; width: 20; height: 20
            onPaint: { const c = getContext("2d"); c.reset(); c.fillStyle = face.dev.ink; c.beginPath(); c.moveTo(0, 0); c.lineTo(18, 10); c.lineTo(0, 20); c.closePath(); c.fill(); }
        }
        Canvas {
            x: face.dev.ax(688); y: -10; width: 20; height: 20
            onPaint: { const c = getContext("2d"); c.reset(); c.fillStyle = face.dev.ink; c.beginPath(); c.moveTo(20, 0); c.lineTo(2, 10); c.lineTo(20, 20); c.closePath(); c.fill(); }
        }
    }

    // ---- what is chosen, and how to do it
    Rule { x: face.dev.ax(193); y: face.dev.ay(1001); width: 591 }
    Glow {
        x: face.dev.ax(196); y: face.dev.ay(1022)
        text: face.note !== "" ? face.note
            : face.going ? face.options[face.sel].doing + "…" : "SELECTED: " + face.options[face.sel].word
        font.pixelSize: 30; font.letterSpacing: 4.2
    }
    Glow {
        x: face.dev.ax(196); y: face.dev.ay(1066)
        text: face.going || face.note !== "" ? "" : face.hint
        font.pixelSize: 24; font.letterSpacing: 6.6
    }
    Slashes { x0: face.dev.ax(703); y0: face.dev.ay(1033); h: 28 }
}
