import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
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
//   workspaces     1 to 6; a dark dot where windows are, the red line under
//                  the one in view. Click to go, scroll to step through.
//   the band       a red line, CASSETTE OS and the Arch logo (click: the
//                  power menu)
//   the readouts   Wi-Fi, volume, battery and its % (click: the control
//                  deck; the wheel: the volume), the time
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    // (above the tube: room for the cartridge standing in the port)
    implicitHeight: Math.ceil(128 * s + lift)
    // with windows open it hides below the screen's edge, and comes up when
    // the pointer goes down to the edge (or a panel of its is open). While
    // it is up it keeps its room, so Hyprland lifts the windows: their
    // frames end 10 px over the bar's tube, its ends under theirs. (The
    // frames' bottom lies frameMargin above the room kept; the tube's top is
    // 8 px of the mock-up below the panel's top.)
    // (only when it comes up for the pointer: up for a widget, it lies over
    // the windows and leaves them be)
    exclusiveZone: bar.reserve && bar.hasWindows
        ? Math.round(128 * s - 8 * s + 10 - Theme.frameMargin) : 0
    WlrLayershell.namespace: "retro-futurism-bar"
    // with the launcher up the bar sits over its stage, out of the blur
    // (set only once the shell has started: a panel made straight onto the
    // overlay layer is not wanted)
    property bool started: false
    Timer { interval: 1500; running: true; onTriggered: bar.started = true }
    WlrLayershell.layer: bar.started && bar.docking ? WlrLayer.Overlay : WlrLayer.Top
    color: "transparent"

    readonly property bool hasWindows: Hypr.windows.length > 0 || Hypr.fullscreen
    property bool hovered: false
    // under the lock it waits below the screen; let in, it comes up and
    // stays a moment before it hides for the windows
    Timer { id: welcome; interval: 2600 }
    Connections {
        target: Scene
        function onUnlocked() { bar.hovered = false; linger.stop(); welcome.restart(); }
        function onLockedChanged() { if (Scene.locked) { bar.hovered = false; linger.stop(); } }
    }
    // a cartridge just in: the bar stays up a moment, to see it
    Connections { target: Cartridges; function onLanded() { welcome.restart(); } }
    readonly property bool reserve: !Scene.locked && (hovered || linger.running || welcome.running)
    readonly property bool shown: !Scene.locked && (!hasWindows || reserve)
        || docking
        || Widgets.current === "power" || Widgets.current === "controls"
    // the launcher: the bar slides right on its arm until its port is under
    // the launcher's slot, and stays there until the cartridge is in
    readonly property bool docking: Widgets.current === "launcher" || Cartridges.flying
    // (to the launcher's slot, where it says; else the screen's middle)
    readonly property real shift: docking ? Math.max(0, (Cartridges.slotX > 0 ? Cartridges.slotX : width / 2) - lx(171)) : 0
    // the cartridge in the port: the window under the pointer's app, else the
    // last launched; and whether this is the bar on the screen in use
    readonly property var portEntry: Cartridges.lastLaunched
    readonly property string portClass: Hypr.activeClass ?? ""
    readonly property bool focusedScreen: (Hyprland.focusedMonitor?.name ?? "") === (bar.screen?.name ?? "")
    Timer { id: linger; interval: 900 }               // a moment after the pointer leaves
    onHoveredChanged: if (!hovered) linger.restart()
    // the windows move when the bar makes room or gives it back: the frames follow
    onReserveChanged: Hypr.look()

    // where the pointer counts: the tube while the bar is up, else a thin
    // strip along the screen's bottom edge
    // (just the tube: the cartridge standing above it lets the pointer through)
    mask: Region { item: bar.shown ? tubeZone : edgeStrip }
    Item { id: edgeStrip; anchors.bottom: parent.bottom; width: parent.width; height: 3 }
    // the tube's place once the bar is up; it does not slide (the pointer must
    // stay inside it all the while the bar rises, or the bar would go again)
    Item { id: tubeZone; y: bar.lift; width: parent.width; height: parent.height - bar.lift }
    HoverHandler { onHoveredChanged: bar.hovered = hovered }

    // ---- the mock-up's pixels to the screen. The pieces are 128 tall (the
    // mock-up's y 312 to 440; the tube itself 320 to 418), the left one
    // from x 20 to 800, the right one from 900 to 2152.
    readonly property real side: Theme.frameMargin         // its ends line up with a window's frame
    // (the pieces span the mock-up's x 20 to 2152; the tube itself 35 to
    // 2139: 15 px of air before it, 13 after, 2004 of tube)
    readonly property real s: Math.min(Theme.taskbarScale, (width - 2 * side) / 2004)
    readonly property real u: s / 0.6                      // for things sized by eye at 0.6
    readonly property real leftX: side - 15 * s            // (the piece has 15 px of air before the tube)
    readonly property real fillW: Math.max(0, width - 2 * side - 2004 * s)
    readonly property real rightX: leftX + 780 * s + fillW
    function lx(x) { return leftX + (x - 20) * s; }       // a point of the left piece
    function rx(x) { return rightX + (x - 900) * s; }     // ... of the right piece
    function my(y) { return lift + (y - 312) * s; }
    // the cartridge in the port: its contacts the port's mouth wide (87-160)
    // (the size of a cartridge in the launcher's slot, so one goes from
    // there into here unchanged)
    readonly property real portS: (227 - 115) * s / 178
    readonly property real lift: Math.ceil(425 * portS - (378 - 312) * s + 6)

    // the look
    readonly property color rust: "#b2512f"
    readonly property color ink: "#35312a"
    readonly property color dotOn: "#706750"
    readonly property color dotOff: "#c3b49e"
    readonly property color paper: "#f6efdf"      // light lettering on the band
    readonly property color amber: "#ffb04c"
    readonly property string face: "Inter"
    readonly property string figures: "Barlow"     // the numbers: workspaces, battery, time
    readonly property real icon: s / 0.78 * 0.74   // the readouts' icons: small and fine

    // everything below slides as one
    Item {
        id: body
        width: parent.width; height: parent.height
        y: bar.shown ? 0 : height + 4
        x: bar.shift
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: bar.shown ? 420 : 260; easing.type: bar.shown ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 0.8 } }


    // ---- the arm the bar rides out on (seen when it is shifted): a mount
    // behind the bar's home place, a chrome sleeve, a rod running into the bar's
    // left end. Behind the bar's pieces; in the bar's own coordinates, so
    // the screen's edge is at -x.
    Item {
        id: arm
        visible: body.x > 1
        // its mount sits where the bar's left end is at home (behind it then)
        readonly property real mount: -body.x + bar.lx(70)
        readonly property real cy: bar.my(369)                  // the tube's middle
        readonly property real sleeveLen: Math.min(420 * bar.s / 0.78, Math.max(0, (bar.lx(60) - mount) * 0.55))
        component Chrome: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.00; color: "#6c6862" }
                GradientStop { position: 0.16; color: "#d9d5ce" }
                GradientStop { position: 0.38; color: "#fbfaf7" }
                GradientStop { position: 0.62; color: "#c9c4bb" }
                GradientStop { position: 0.86; color: "#8f8a82" }
                GradientStop { position: 1.00; color: "#55514b" }
            }
        }
        // the rod (thinner), from the sleeve into the bar's end
        Chrome {
            x: arm.mount + 18 + arm.sleeveLen - 12; width: bar.lx(60) - x
            y: arm.cy - height / 2; height: 17 * bar.s / 0.78
            radius: height / 2
        }
        // the sleeve
        Chrome {
            x: arm.mount + 14; width: arm.sleeveLen
            y: arm.cy - height / 2; height: 30 * bar.s / 0.78
            radius: 5
            Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.width: 1; border.color: "#4e4a44" }
        }
        // a collar where the rod comes out
        Rectangle {
            x: arm.mount + 14 + arm.sleeveLen - 10; width: 16 * bar.s / 0.78
            y: arm.cy - height / 2; height: 40 * bar.s / 0.78
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f4ebdc" }
                GradientStop { position: 0.6; color: "#e3d5bf" }
                GradientStop { position: 1.0; color: "#b8a88e" }
            }
            border.width: 1; border.color: "#8d7f68"
        }
        // the mount on the screen's edge: a cream plate, a rust corner, two bolts
        Rectangle {
            x: arm.mount - 8; width: 30 * bar.s / 0.78
            y: arm.cy - height / 2; height: 74 * bar.s / 0.78
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f4ebdc" }
                GradientStop { position: 0.55; color: "#e6d9c4" }
                GradientStop { position: 1.0; color: "#c9b99e" }
            }
            border.width: 1; border.color: "#9a8a70"
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 3; y: 4; width: 6; height: parent.height - 8; radius: 2; color: "#b2512f" }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: parent.width * 0.42 - width / 2; y: index === 0 ? 9 : parent.height - 9 - height
                    width: 9 * bar.s / 0.78; height: width; radius: width / 2
                    color: "#a39886"; border.width: 1; border.color: "#5d5547"
                }
            }
        }
    }

    // ---- the bar itself
    Image {
        x: bar.leftX; y: bar.lift; width: 780 * bar.s; height: 128 * bar.s
        source: Quickshell.shellPath("assets/taskbar/left.png")
        smooth: true; mipmap: true
    }
    Image {
        x: bar.leftX + 780 * bar.s; y: bar.lift; width: bar.fillW + 0.5; height: 128 * bar.s
        visible: bar.fillW > 0
        source: Quickshell.shellPath("assets/taskbar/fill.png")
        fillMode: Image.Stretch
        smooth: true
    }
    Image {
        x: bar.rightX; y: bar.lift; width: 1252 * bar.s; height: 128 * bar.s
        source: Quickshell.shellPath("assets/taskbar/right.png")
        smooth: true; mipmap: true
    }

    component Sep: Rectangle {
        property real k: 1                  // (handed in: the bar's scale, the tube's middle)
        property real cy: 0
        width: Math.max(1, 1.6 * k); height: 28 * k
        y: cy - height / 2
        color: "#3a352d"; opacity: 0.4
    }

    // the tube itself (for the pointer)

    // ======== the cartridge in the port: the window under the pointer's app
    // (focus follows the pointer), else the last one launched. It stands in
    // the slot, its contacts out of sight in it; a click: the launcher.
    Item {
        id: portStand
        readonly property bool has: (bar.portClass !== "" || bar.portEntry !== null) && !Cartridges.flying
        x: bar.lx(171) - 175 * bar.portS
        width: has ? 350 * bar.portS : 0
        height: has ? bar.my(374) : 0
        clip: true
        Cartridge {
            windowClass: bar.portClass
            entry: bar.portEntry
            scale: bar.portS
            transformOrigin: Item.TopLeft
            y: bar.my(378) - 425 * bar.portS
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Widgets.toggle("launcher")
        }
    }
    // where a cartridge stands in this bar's port, for one on its way there
    // (the bar on the screen in use; the bar's place once it is up)
    Binding { target: Cartridges; property: "portX"; value: bar.lx(171) + bar.shift; when: bar.focusedScreen === true }
    Binding { target: Cartridges; property: "portY"; value: (bar.screen ? bar.screen.height : 0) - bar.implicitHeight + bar.my(378); when: bar.focusedScreen === true }
    Binding { target: Cartridges; property: "portS"; value: bar.portS; when: bar.focusedScreen === true }
    Binding { target: Cartridges; property: "portClipY"; value: (bar.screen ? bar.screen.height : 0) - bar.implicitHeight + bar.my(374); when: bar.focusedScreen === true }

    // ======== the port: where the app cartridges go in (plate 52-290). The
    // port itself is in the picture (bezel 104-238 x 350-386, its mouth
    // 115-227 x 355-381, four contacts on its floor from x 125.7, y 369.8).
    // While the launcher is open its contacts glow warm, as if live.
    Item {
        id: port
        x: bar.lx(52); y: bar.my(339)
        width: 238 * bar.s; height: 58 * bar.s
        readonly property bool lit: Widgets.current === "launcher"
        // the bezel catches a little light under the pointer
        Rectangle {
            x: (104 - 52) * bar.s; y: (350 - 339) * bar.s
            width: 134 * bar.s; height: 36 * bar.s; radius: 5.8 * bar.s
            color: "transparent"
            border.width: Math.max(1, 1.2 * bar.s); border.color: "#fffaf0"
            opacity: portMouse.containsMouse ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        // the contacts, live: a warm light on each, and on the floor below
        Item {
            opacity: port.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: (125.7 + index * 24.8 - 52) * bar.s; y: (369.8 - 339) * bar.s
                    width: 16.2 * bar.s; height: 9 * bar.s; radius: 1.3 * bar.s
                    color: "#ffd27a"; opacity: 0.45
                }
            }
            Rectangle {
                x: (117 - 52) * bar.s; y: (358 - 339) * bar.s
                width: 108 * bar.s; height: 12 * bar.s; radius: 2 * bar.s
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00ffb04c" }
                    GradientStop { position: 1.0; color: "#55ffb04c" }
                }
            }
        }
        MouseArea {
            id: portMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Widgets.toggle("launcher")
        }
    }

    // ======== workspaces (plate 209-712): nine places, evenly
    Item {
        id: spaces
        x: bar.lx(304); y: bar.my(339)
        width: 408 * bar.s; height: 58 * bar.s
        readonly property real step: 56 * bar.s
        Repeater {
            model: Hypr.ids.slice(0, 6)
            Item {
                id: cell
                required property int modelData
                required property int index
                readonly property bool active: modelData === Hypr.activeId
                readonly property var st: Hypr.spaces[modelData] ?? ({ occupied: false, urgent: false })
                x: (380 - 304) * bar.s + index * spaces.step - width / 2
                width: spaces.step; height: spaces.height
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.top
                    anchors.verticalCenterOffset: (362 - 339) * bar.s
                    text: cell.modelData
                    color: bar.ink
                    opacity: cell.active || cellMouse.containsMouse ? 1 : 0.7
                    font.family: bar.figures
                    font.pixelSize: Math.round(21 * bar.s)
                    font.weight: cell.active ? Font.ExtraBold : Font.Bold
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
            color: archMouse.containsMouse || Widgets.current === "power" ? bar.amber : bar.paper
            MouseArea {
                id: archMouse
                anchors.fill: parent; anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.toggle("power")
            }
        }
    }
    Rectangle {
        // the red line, as on the mock-up (from x 747), up to the brand
        x: bar.lx(747)
        width: brand.x - x - 40 * bar.s
        y: bar.my(368.5) - height / 2
        height: Math.max(1.5, 4 * bar.s); radius: height / 2
        color: bar.rust
    }

    // ======== the readouts (plate 1645-2120), where the mock-up has them
    // Wi-Fi: three arcs and a dot, lit to the signal (mock-up x 1711)
    Canvas {
        id: wifi
        width: 24; height: 20; scale: bar.icon
        x: bar.rx(1703) - width / 2; y: bar.my(368) - height / 2
        readonly property int level: !Net.online ? 0 : Net.wired ? 3 : Math.max(1, Math.ceil(Net.signal * 3))
        onLevelChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const cx = width / 2, cy = height - 2;
            c.lineCap = "round"; c.lineWidth = 3.4;
            for (let i = 1; i <= 3; i++) {
                c.strokeStyle = bar.ink;
                c.globalAlpha = i <= level ? 1 : 0.22;
                c.beginPath(); c.arc(cx, cy, 4 + i * 4.6, Math.PI * 1.25, Math.PI * 1.75); c.stroke();
            }
            c.globalAlpha = level > 0 ? 1 : 0.4;
            c.fillStyle = bar.ink; c.beginPath(); c.arc(cx, cy - 1, 3.0, 0, Math.PI * 2); c.fill();
        }
    }
    Sep { k: bar.s; cy: bar.my(368); x: bar.rx(1737) }
    // volume: the speaker and as many waves as it is loud (x 1791)
    Canvas {
        id: vol
        width: 26; height: 20; scale: bar.icon
        x: bar.rx(1771) - width / 2; y: bar.my(368) - height / 2
        readonly property int waves: Audio.muted ? -1 : Audio.volume <= 0.01 ? 0 : Audio.volume < 0.4 ? 1 : 2
        onWavesChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            c.fillStyle = bar.ink; c.strokeStyle = bar.ink;
            c.beginPath();
            c.moveTo(2, 7); c.lineTo(6, 7); c.lineTo(11, 2.5); c.lineTo(11, 17.5); c.lineTo(6, 13); c.lineTo(2, 13);
            c.closePath(); c.fill();
            c.lineWidth = 3.4; c.lineCap = "round";
            if (waves < 0) {
                c.beginPath(); c.moveTo(15, 6.5); c.lineTo(22, 13.5); c.moveTo(22, 6.5); c.lineTo(15, 13.5); c.stroke();
            }
            for (let i = 1; i <= waves; i++) {
                c.beginPath(); c.arc(11, 10, 3.5 + i * 4, -Math.PI * 0.3, Math.PI * 0.3); c.stroke();
            }
        }
    }
    Sep { k: bar.s; cy: bar.my(368); x: bar.rx(1806) }
    // battery: one smooth bar, as full as the battery (x 1888); amber
    // while charging, rust when low
    Item {
        id: batt
        width: 38; height: 18; scale: bar.icon
        x: bar.rx(1851) - width / 2; y: bar.my(368) - height / 2
        visible: Power.present
        readonly property color tone: Power.low ? bar.rust : Power.charging ? "#c98a2c" : bar.ink
        Rectangle {
            width: 34; height: 18; radius: 5
            color: "transparent"; border.width: 2.8; border.color: bar.ink
            Rectangle {
                x: 4; y: 4
                height: parent.height - 8; radius: 2
                width: Math.max(height, (parent.width - 8) * Power.percent / 100)
                color: batt.tone
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Rectangle { x: 35; y: 5.5; width: 3.4; height: 7; radius: 1.5; color: bar.ink }
    }
    // the battery's figure, beside it
    Text {
        visible: Power.present
        x: bar.rx(1890)
        y: bar.my(368) - height / 2
        text: Power.percent + "%"
        color: Power.low ? bar.rust : bar.ink
        opacity: 0.85
        font.family: bar.figures
        font.pixelSize: Math.round(18 * bar.s)
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
    }
    Sep { k: bar.s; cy: bar.my(368); x: bar.rx(1954); visible: Power.present }
    // Wi-Fi, volume and the battery: one place to click for the control
    // deck (widgets/controls), the wheel for the volume
    MouseArea {
        x: bar.rx(1660); width: bar.rx(1950) - x
        y: bar.my(330); height: bar.my(408) - y
        cursorShape: Qt.PointingHandCursor
        onClicked: Widgets.toggle("controls")
        onWheel: e => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
    // the time: a click brings up the clock (widgets/clock)
    MouseArea {
        x: bar.rx(1962); width: bar.rx(2100) - x
        y: bar.my(330); height: bar.my(408) - y
        cursorShape: Qt.PointingHandCursor
        onClicked: Widgets.toggle("clock")
    }
    // the time, centred where the mock-up's was (x 2028)
    Text {
        x: bar.rx(2025) - width / 2
        y: bar.my(368) - height / 2
        text: Clock.time
        color: bar.ink
        font.family: bar.figures
        font.pixelSize: Math.round(24 * bar.s)
        font.weight: Font.Bold
        font.letterSpacing: 1 * bar.s
        font.features: { "tnum": 1 }
    }
    }
}
