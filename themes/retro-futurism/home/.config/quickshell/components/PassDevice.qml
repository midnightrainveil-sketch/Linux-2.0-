import QtQuick
import QtQuick.Effects
import Quickshell

// The silver Kairo device of the lock screen's pass and of the power
// widget (art/Login0.png, lifted off by tools/make_pass.py): its picture,
// what glows on its face, its buttons and its roller.
//
// It is drawn in the mock-up's own pixels (1162 x 1201; pass.png starts at
// the mock-up's 38, 26): scale it from outside. Put what glows on its face
// inside it (they glow: a halo close round them, and a wide one behind),
// placed with ax() and ay():
//
//   PassDevice {
//       scale: 0.6; transformOrigin: Item.TopLeft
//       onEnter: ...
//       Text { x: dev.ax(193); y: dev.ay(262); text: "..." }
//   }
//
//   signals    pause (‖), power, user, session, back (◀◀), enter (the roller
//              clicked, ▶▶ … unless forward is connected), forward (▶▶),
//              rolled(steps): the wheel over the device, a step a notch
//   roll(n)    turn the roller n ridges (animated); rolled also turns it
//   lamp       the red lamp on top lit
Item {
    id: dev

    width: 1162
    height: 1201
    function ax(x) { return x - 38; }
    function ay(y) { return y - 26; }

    readonly property color ink: "#f2f8ff"
    property bool lamp: false
    property bool forwardIsEnter: true           // ▶▶ as enter (else 'forward')
    default property alias face: glowing.data

    signal pause()
    signal power()
    signal user()
    signal session()
    signal back()
    signal enter()
    signal forward()
    signal rolled(int steps)

    // ---- the roller: turned by the wheel (or by roll()); a notch a ridge
    readonly property int ridges: 16
    property real phase: 0                          // in ridges
    Behavior on phase { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    function roll(n: real): void { phase += n; }

    Image {
        anchors.fill: parent
        source: Quickshell.shellPath("assets/pass.png")
        smooth: true; mipmap: true
    }

    // the wheel anywhere over the device: one step a notch (touchpads add up)
    property real wheelRest: 0
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            dev.wheelRest += e.angleDelta.y;
            const steps = Math.trunc(dev.wheelRest / 120);
            if (steps !== 0) {
                dev.wheelRest -= steps * 120;
                dev.roll(-steps);
                dev.rolled(-steps);            // down the page: on down the list
            }
        }
    }

    // ---- what glows on its face: a bright halo close round every stroke,
    // and the same light spread wide behind it, as a backlit screen bleeds
    // into the glass over it
    MultiEffect {
        source: glowing
        anchors.fill: glowing
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        colorization: 1.0
        colorizationColor: "#c4e2ff"
        brightness: 0.45
        opacity: 0.95
    }
    Item {
        id: glowing
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#dcefff"
            shadowBlur: 0.55
            shadowOpacity: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 24
            brightness: 0.06
        }
    }

    // ---- the red lamp on top
    Rectangle {
        x: dev.ax(1006); y: dev.ay(205); width: 63; height: 16; radius: 8
        color: "#ff4a3a"
        opacity: dev.lamp ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Rectangle { anchors.centerIn: parent; width: parent.width + 26; height: parent.height + 22; radius: height / 2; color: "#ff4a3a"; opacity: 0.25 }
    }

    // ---- the roller (909-1041 x 641-722): a knurled cylinder, its ridges
    // going round as it turns
    Canvas {
        id: roller
        x: dev.ax(909); y: dev.ay(641); width: 132; height: 81
        readonly property real phase: dev.phase
        onPhaseChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const w = width, h = height, R = h / 2, cy = h / 2;
            c.save();
            c.beginPath(); c.roundedRect(0.5, 0.5, w - 1, h - 1, 7, 7); c.clip();
            // the metal: bright across its middle, dark where it turns away
            const g = c.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0.00, "#6f7174"); g.addColorStop(0.18, "#c9cbcd");
            g.addColorStop(0.42, "#fafbfb"); g.addColorStop(0.62, "#e9eaeb");
            g.addColorStop(0.86, "#a9abae"); g.addColorStop(1.00, "#5c5e61");
            c.fillStyle = g; c.fillRect(0, 0, w, h);
            // the ridges: grooves round the cylinder, crowding at its edges
            const n = dev.ridges;
            for (let i = 0; i < n; i++) {
                const a = ((i + roller.phase) / n) * Math.PI * 2;
                const s = Math.sin(a), co = Math.cos(a);
                if (co <= 0.05) continue;                      // round the back
                const y = cy + R * 0.98 * s;
                const lw = 0.7 + 1.5 * co;
                c.fillStyle = Qt.rgba(0.22, 0.23, 0.25, 0.16 + 0.34 * co);
                c.fillRect(3, y - lw / 2, w - 6, lw);
                c.fillStyle = Qt.rgba(1, 1, 1, 0.75 * co);   // the lit edge under it
                c.fillRect(3, y + lw / 2, w - 6, Math.max(0.8, lw * 0.7));
            }
            // its rounded ends, in shadow
            const e = c.createLinearGradient(0, 0, w, 0);
            e.addColorStop(0, "rgba(0,0,0,0.30)"); e.addColorStop(0.06, "rgba(0,0,0,0)");
            e.addColorStop(0.94, "rgba(0,0,0,0)"); e.addColorStop(1, "rgba(0,0,0,0.30)");
            c.fillStyle = e; c.fillRect(0, 0, w, h);
            c.restore();
        }
    }

    // ---- the buttons
    component Press: Item {
        id: press
        signal hit()
        property real r: 18
        Rectangle {
            anchors.fill: parent; radius: press.r
            color: "#1d2024"
            opacity: area.pressed ? 0.22 : area.containsMouse ? 0.07 : 0
            Behavior on opacity { NumberAnimation { duration: 70 } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: press.hit()
        }
    }
    Press { x: dev.ax(855); y: dev.ay(190); width: 85; height: 42; r: 21; onHit: dev.pause() }
    Press { x: dev.ax(865); y: dev.ay(300); width: 205; height: 38; r: 19; onHit: dev.power() }
    Press { x: dev.ax(917); y: dev.ay(403); width: 98; height: 38; r: 19; onHit: dev.user() }
    Press { x: dev.ax(897); y: dev.ay(505); width: 136; height: 38; r: 19; onHit: dev.session() }
    Press { x: dev.ax(835); y: dev.ay(640); width: 70; height: 82; r: 30; onHit: dev.back() }
    Press { x: dev.ax(908); y: dev.ay(630); width: 132; height: 90; r: 12; onHit: dev.enter() }
    Press {
        x: dev.ax(1045); y: dev.ay(640); width: 65; height: 82; r: 30
        onHit: dev.forwardIsEnter ? dev.enter() : dev.forward()
    }
}
