import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The taskbar: the mock-up itself (art/TaskbarEg.png) along the foot of the
// screen, with what it shows drawn live in the places the mock-up has them.
// Its pictures (assets/taskbar, made by tools/make_taskbar.py) are the bar
// with those things erased, in three pieces: the left end, a slice of the
// band stretched to fit the screen, and the right end.
//
//   the port       the slot the app cartridges go in: click for the launcher
//   workspaces     1 to 9; a dark dot where windows are, the red line under
//                  the one in view. Click to go, scroll to step through.
//   the band       the window in use, a red line, CASSETTE OS and the Arch
//                  logo (click: the power menu)
//   the readouts   Wi-Fi (click: nmtui), volume (scroll; click mutes),
//                  battery (click: the next power profile), the time
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Math.ceil(128 * s)
    exclusiveZone: Math.ceil((128 - 8) * s)
    WlrLayershell.namespace: "retro-futurism-bar"
    color: "transparent"

    // ---- the mock-up's pixels to the screen. The pieces are 128 tall (the
    // mock-up's y 312 to 440; the tube itself 320 to 418), the left one
    // from x 20 to 800, the right one from 900 to 2152.
    readonly property real side: Math.round(width * 0.04)     // as in the reference: 4 % each side
    readonly property real s: Math.min(Theme.taskbarScale, (width - 2 * side) / 2032)
    readonly property real u: s / 0.6                      // for things sized by eye at 0.6
    readonly property real leftX: side - 15 * s            // (the piece has 15 px of air before the tube)
    readonly property real fillW: Math.max(0, width - 2 * side - 2032 * s)
    readonly property real rightX: leftX + 780 * s + fillW
    function lx(x) { return leftX + (x - 20) * s; }       // a point of the left piece
    function rx(x) { return rightX + (x - 900) * s; }     // ... of the right piece
    function my(y) { return (y - 312) * s; }

    // the look
    readonly property color rust: "#b2512f"
    readonly property color ink: "#35312a"
    readonly property color dotOn: "#706750"
    readonly property color dotOff: "#c3b49e"
    readonly property color paper: "#f6efdf"      // light lettering on the band
    readonly property color amber: "#ffb04c"
    readonly property string face: "Inter"

    // ---- the bar itself
    Image {
        x: bar.leftX; width: 780 * bar.s; height: 128 * bar.s
        source: Quickshell.shellPath("assets/taskbar/left.png")
        smooth: true; mipmap: true
    }
    Image {
        x: bar.leftX + 780 * bar.s; width: bar.fillW + 0.5; height: 128 * bar.s
        visible: bar.fillW > 0
        source: Quickshell.shellPath("assets/taskbar/fill.png")
        fillMode: Image.Stretch
        smooth: true
    }
    Image {
        x: bar.rightX; width: 1252 * bar.s; height: 128 * bar.s
        source: Quickshell.shellPath("assets/taskbar/right.png")
        smooth: true; mipmap: true
    }

    component Sep: Rectangle {
        width: Math.max(1, 2.4 * bar.s); height: 38 * bar.s
        y: bar.my(368) - height / 2
        color: "#3a352d"; opacity: 0.75
    }

    // ======== the port: where the app cartridges go in (plate 52-195). The
    // slot itself is in the picture; here its lamp (the lens at 179,369)
    // lights while the launcher is open, and a click opens it.
    Item {
        id: port
        x: bar.lx(52); y: bar.my(339)
        width: 143 * bar.s; height: 58 * bar.s
        readonly property bool lit: Panels.open === "launcher"
        // the bezel catches a little light under the pointer
        Rectangle {
            x: (63 - 52) * bar.s; y: (351 - 339) * bar.s
            width: 100 * bar.s; height: 36 * bar.s; radius: 6 * bar.s
            color: "transparent"
            border.width: Math.max(1, 1.4 * bar.s); border.color: "#fff6dc"
            opacity: portMouse.containsMouse && !port.lit ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        // the lamp, lit: an amber lens and its glow
        Rectangle {
            x: (179 - 52) * bar.s - width / 2; y: (369 - 339) * bar.s - height / 2
            width: 9.2 * bar.s; height: width; radius: width / 2
            color: bar.amber
            opacity: port.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 2.8; height: width; radius: width / 2
                color: bar.amber; opacity: 0.25
            }
            Rectangle {   // the lens's glint
                x: parent.width * 0.2; y: parent.height * 0.12
                width: parent.width * 0.32; height: width * 0.8; radius: width / 2
                color: "#fffbe8"; opacity: 0.85
            }
        }
        MouseArea {
            id: portMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("launcher")
        }
    }

    // ======== workspaces (plate 209-712): nine places, evenly
    Item {
        id: spaces
        x: bar.lx(209); y: bar.my(339)
        width: 503 * bar.s; height: 58 * bar.s
        readonly property real step: 53 * bar.s
        Repeater {
            model: Hypr.ids.slice(0, 9)
            Item {
                id: cell
                required property int modelData
                required property int index
                readonly property bool active: modelData === Hypr.activeId
                readonly property var st: Hypr.state[modelData] ?? ({ occupied: false, urgent: false })
                x: (248 - 209) * bar.s + index * spaces.step - width / 2
                width: spaces.step; height: spaces.height
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: (362 - 339) * bar.s
                    text: cell.modelData
                    color: bar.ink
                    opacity: cell.active || cellMouse.containsMouse ? 1 : 0.85
                    font.family: bar.face
                    font.pixelSize: Math.round(25 * bar.s)
                    font.weight: cell.active ? Font.DemiBold : Font.Medium
                }
                // the mark under it: the red line for the one in view, else a
                // dot (dark where windows are)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (380 - 339) * bar.s - height / 2
                    width: (cell.active ? 38 : 9) * bar.s
                    height: (cell.active ? 6 : 9) * bar.s
                    radius: height / 2
                    color: cell.active || cell.st.urgent ? bar.rust
                         : cell.st.occupied ? bar.dotOn : bar.dotOff
                    Behavior on width { NumberAnimation { duration: 140 } }
                }
                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.workspace(cell.modelData)
                }
            }
        }
        WheelHandler {
            onWheel: e => Hypr.relativeWorkspace(e.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // ======== the band: the window in use, then the red line; at its right
    // end /// CASSETTE OS | Arch, ending where the mock-up's A did (x 1615)
    Row {
        id: brand
        x: bar.rx(1618) - width
        y: bar.my(368) - height / 2
        height: 34 * bar.s
        spacing: 22 * bar.s
        Item {
            // the three slashes, as the mock-up has them
            anchors.verticalCenter: parent.verticalCenter
            width: 76 * bar.s; height: 34 * bar.s
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: index * 26 * bar.s
                    width: 13 * bar.s; height: 34 * bar.s; radius: 1.5 * bar.s
                    color: "#e8decb"; opacity: 0.92
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.62, 0, 21 * bar.s, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CASSETTE OS"
            color: bar.paper
            font.family: bar.face
            font.pixelSize: Math.round(23 * bar.s)
            font.weight: Font.Bold
            font.letterSpacing: 7 * bar.s
            style: Text.Raised; styleColor: "#55563f"
        }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(1, 2.6 * bar.s); height: 36 * bar.s; color: bar.paper; opacity: 0.75 }
        ArchLogo {
            anchors.verticalCenter: parent.verticalCenter
            width: 36 * bar.s; height: 36 * bar.s
            color: archMouse.containsMouse || Panels.open === "power" ? bar.amber : bar.paper
            MouseArea {
                id: archMouse
                anchors.fill: parent; anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("power")
            }
        }
    }
    Text {
        id: title
        x: bar.lx(747)
        y: bar.my(368) - height / 2
        width: Math.min(implicitWidth, brand.x - x - 120 * bar.s)
        text: Hypr.activeTitle.toUpperCase()
        elide: Text.ElideRight
        color: "#2a2b20"
        font.family: bar.face
        font.pixelSize: Math.round(20 * bar.s)
        font.weight: Font.DemiBold
        font.letterSpacing: 2.6 * bar.s
    }
    Rectangle {
        // the red line, as on the mock-up, from the title to the brand
        x: title.text === "" ? bar.lx(747) : title.x + title.width + 26 * bar.s
        width: brand.x - x - 40 * bar.s
        y: bar.my(368.5) - height / 2
        height: Math.max(1.5, 4 * bar.s); radius: height / 2
        color: bar.rust
    }

    // ======== the readouts (plate 1645-2120), where the mock-up has them
    // Wi-Fi: three arcs and a dot, lit to the signal (mock-up x 1711)
    Canvas {
        id: wifi
        width: 24; height: 20; scale: bar.u
        x: bar.rx(1711) - width / 2; y: bar.my(368) - height / 2
        readonly property int level: !Net.online ? 0 : Net.wired ? 3 : Math.max(1, Math.ceil(Net.signal * 3))
        onLevelChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const cx = width / 2, cy = height - 2;
            c.lineCap = "round"; c.lineWidth = 2.6;
            for (let i = 1; i <= 3; i++) {
                c.strokeStyle = bar.ink;
                c.globalAlpha = i <= level ? 1 : 0.22;
                c.beginPath(); c.arc(cx, cy, 4 + i * 4.6, Math.PI * 1.25, Math.PI * 1.75); c.stroke();
            }
            c.globalAlpha = level > 0 ? 1 : 0.4;
            c.fillStyle = bar.ink; c.beginPath(); c.arc(cx, cy - 1, 2.4, 0, Math.PI * 2); c.fill();
        }
        MouseArea {
            anchors.fill: parent; anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached([Settings.terminal, "-e", "nmtui"])
        }
    }
    Sep { x: bar.rx(1750) }
    // volume: the speaker and as many waves as it is loud (x 1791)
    Canvas {
        id: vol
        width: 26; height: 20; scale: bar.u
        x: bar.rx(1791) - width / 2; y: bar.my(368) - height / 2
        readonly property int waves: Audio.muted ? -1 : Audio.volume <= 0.01 ? 0 : Audio.volume < 0.4 ? 1 : 2
        onWavesChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            c.fillStyle = bar.ink; c.strokeStyle = bar.ink;
            c.beginPath();
            c.moveTo(2, 7); c.lineTo(6, 7); c.lineTo(11, 2.5); c.lineTo(11, 17.5); c.lineTo(6, 13); c.lineTo(2, 13);
            c.closePath(); c.fill();
            c.lineWidth = 2.4; c.lineCap = "round";
            if (waves < 0) {
                c.beginPath(); c.moveTo(15, 6.5); c.lineTo(22, 13.5); c.moveTo(22, 6.5); c.lineTo(15, 13.5); c.stroke();
            }
            for (let i = 1; i <= waves; i++) {
                c.beginPath(); c.arc(11, 10, 3.5 + i * 4, -Math.PI * 0.3, Math.PI * 0.3); c.stroke();
            }
        }
        MouseArea {
            anchors.fill: parent; anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.toggleMute()
            onWheel: e => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Sep { x: bar.rx(1833) }
    // battery: one smooth bar, as full as the battery (x 1888); amber
    // while charging, rust when low
    Item {
        id: batt
        width: 38; height: 18; scale: bar.u
        x: bar.rx(1888) - width / 2; y: bar.my(368) - height / 2
        visible: Power.present
        readonly property color tone: Power.low ? bar.rust : Power.charging ? "#c98a2c" : bar.ink
        Rectangle {
            width: 34; height: 18; radius: 5
            color: "transparent"; border.width: 1.8; border.color: bar.ink
            Rectangle {
                x: 3.5; y: 3.5
                height: parent.height - 7; radius: 2.5
                width: Math.max(height, (parent.width - 7) * Power.percent / 100)
                color: batt.tone
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Rectangle { x: 35; y: 6; width: 2.6; height: 6; radius: 1.3; color: bar.ink }
        MouseArea {
            anchors.fill: parent; anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const p = Power.profiles, i = p.indexOf(Power.profile);
                Power.setProfile(p[(i + 1) % p.length]);
            }
        }
    }
    Sep { x: bar.rx(1954); visible: Power.present }
    // the time, centred where the mock-up's was (x 2028)
    Text {
        x: bar.rx(2028) - width / 2
        y: bar.my(368) - height / 2
        text: Clock.time
        color: bar.ink
        font.family: bar.face
        font.pixelSize: Math.round(31 * bar.s)
        font.weight: Font.Medium
        font.letterSpacing: 2 * bar.s
        font.features: { "tnum": 1 }
    }
}
