import QtQuick
import QtQuick.Shapes
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
//   the band       a red line, MAGNETIC 88 and the Arch logo (click: the
//                  power menu)
//   the readouts   Wi-Fi, volume, battery and its % (click: the control
//                  deck; the wheel: the volume), the time
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    // (above the tube: room for the cartridge standing in the port; below
    // it, the margin the windows' rims keep from the screen's edge, so the
    // tube's foot lies on theirs)
    implicitHeight: Math.ceil(lift + 106 * s) + Theme.frameMargin
    // With windows open it hides below the screen's edge, and comes up when
    // the pointer goes down to the edge (or a panel of its is open). It
    // comes up over the windows and leaves them where they are: its tube
    // lies over the foot of the windows' rims, its rounded ends on the
    // rims' bottom corners (the same radius: Theme.windowRounding plus the
    // rim), its ends and foot on theirs.
    exclusiveZone: 0
    WlrLayershell.namespace: "retro-futurism-bar"
    // with the launcher up the bar sits over its stage, out of the blur
    // (set only once the shell has started: a panel made straight onto the
    // overlay layer is not wanted)
    property bool started: false
    Timer { interval: 1500; running: true; onTriggered: bar.started = true }
    WlrLayershell.layer: bar.started && bar.docking ? WlrLayer.Overlay : WlrLayer.Top
    color: "transparent"

    readonly property bool hasWindows: Hypr.apps.length > 0 || Hypr.fullscreen
    readonly property bool hovered: hover.hovered
    // under the lock it waits below the screen; let in, it comes up and
    // stays a moment before it hides for the windows (it is made afresh
    // then, shell.qml: so it comes up as it is made)
    Timer { id: welcome; interval: 2600; running: !Scene.locked }
    Connections {
        target: Scene
        function onUnlocked() { linger.stop(); welcome.restart(); }
        function onLockedChanged() { if (Scene.locked) linger.stop(); }
    }
    // a cartridge just in: the bar stays up a moment, to see it
    Connections { target: Cartridges; function onLanded() { welcome.restart(); justIn.restart(); } }
    readonly property bool called: !Scene.locked && (hovered || linger.running || welcome.running)
    readonly property bool shown: !Scene.locked && (!hasWindows || called)
        || docking
        || Widgets.current === "power" || Widgets.current === "controls"
    // the launcher: the bar slides right on its arm until its port is under
    // the launcher's slot, and stays there until the cartridge is in
    readonly property bool docking: Widgets.current === "launcher" || Cartridges.flying
    // (to the launcher's slot, where it says; else the screen's middle)
    readonly property real shift: docking ? Math.max(0, (Cartridges.slotX > 0 ? Cartridges.slotX : width / 2) - lx(171)) : 0
    // the cartridge in the port: the window under the pointer's app, else the
    // last launched; and whether this is the bar on the screen in use
    // (only the app of a window on the workspace in view: an empty one, an
    // empty port. Just after a launch the cartridge put in stays a moment,
    // while its window is on its way.)
    Timer { id: justIn; interval: 6000 }
    readonly property var portEntry: justIn.running ? Cartridges.lastLaunched : null
    readonly property string portClass: Hypr.activeClass ?? ""
    readonly property bool focusedScreen: (Hyprland.focusedMonitor?.name ?? "") === (bar.screen?.name ?? "")
    Timer { id: linger; interval: 120 }               // a moment after the pointer leaves (only to ride out a slip off its edge)
    onHoveredChanged: if (!hovered) linger.restart()

    // where the pointer counts: the tube while the bar is up, else a thin
    // strip along the screen's bottom edge
    // (just the tube: the cartridge standing above it lets the pointer through)
    mask: Region { item: bar.shown ? tubeZone : edgeStrip }
    Item { id: edgeStrip; anchors.bottom: parent.bottom; width: parent.width; height: 3 }
    // the tube's place once the bar is up; it does not slide (the pointer must
    // stay inside it all the while the bar rises, or the bar would go again)
    Item { id: tubeZone; y: bar.lift; width: parent.width; height: parent.height - bar.lift }
    HoverHandler { id: hover }

    // ---- the mock-up's pixels to the screen. The pieces are 128 tall (the
    // mock-up's y 312 to 440; the tube itself 320 to 418), the left one
    // from x 20 to 800, the right one from 900 to 2152.
    readonly property real side: Theme.frameMargin         // its ends line up with a window's frame
    // (the pieces span the mock-up's x 20 to 2152; the tube itself 35 to
    // 2139: 15 px of air before it, 13 after, 2004 of tube)
    // (from the screen's width, which is there from the start: the bar's
    // own is not known until the compositor has answered)
    readonly property real s: Math.max(0.3, Math.min(Theme.taskbarScale, ((bar.screen?.width ?? 1920) - 2 * side) / 2004))
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

    // ======== the cartridge in the port: the app of the window in use on the
    // workspace in view (focus follows the pointer); nothing on an empty
    // workspace. It stands in the slot, its contacts out of sight in it; a
    // click: the launcher.
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
    // end /// MAGNETIC 88 | Arch, ending where the mock-up's A did (x 1615)
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
        // (in an Item as wide as the letters without the spacing after the
        // last one: so the gaps either side of the name are the same)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: brandName.implicitWidth - brandName.font.letterSpacing; height: brandName.implicitHeight
            Text {
                id: brandName
                text: "MAGNETIC 88"
                color: bar.paper
                font.family: bar.face
                font.pixelSize: Math.round(23 * bar.s)
                font.weight: Font.Bold
                font.letterSpacing: 7 * bar.s
                style: Text.Raised; styleColor: "#55563f"
            }
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

    // ======== the readouts (plate 1645-2120): Wi-Fi, volume and the battery
    // (a click: the control deck; the wheel: the volume), then the date and
    // the time (a click: the clock). Drawn, so they stay crisp at any size,
    // in the plate's ink: a signal meter, a volume knob, a slim battery.
    component Divider: Rectangle {
        property real k: 1
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Math.max(1, 1.6 * k); height: 28 * k
        color: "#3a352d"; opacity: 0.4
    }
    Row {
        id: readouts
        x: bar.rx(2104) - width
        y: bar.my(368) - height / 2
        height: 40 * bar.s
        spacing: 20 * bar.s

        // ---- the state of things: one place to click for the deck
        Item {
            width: readings.width; height: parent.height
            Row {
                id: readings
                height: parent.height
                spacing: 20 * bar.s

                // Wi-Fi: four bars, as many dark as the signal is strong
                Row {
                    id: wifi
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3.2 * bar.s
                    readonly property int level: !Net.online ? 0 : Net.wired ? 4 : Math.max(1, Math.ceil(Net.signal * 4))
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 4.6 * bar.s; height: (8 + index * 5) * bar.s; radius: 1.4 * bar.s
                            color: bar.ink
                            opacity: index < wifi.level ? 1 : 0.2
                        }
                    }
                }
                Divider { k: bar.s }

                // volume: a knob, its marker turned as far as it is loud
                // (from 7 to 5 o'clock), the turned part of its scale dark;
                // muted, struck through
                Shape {
                    id: knob
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28 * bar.s; height: 28 * bar.s
                    // (the standard renderer, smoothed by multisampling: the curve
                    // renderer drew nothing for it)
                    layer.enabled: true
                    layer.samples: 8
                    layer.smooth: true
                    readonly property real r: 11.2 * bar.s
                    readonly property real cx: width / 2
                    readonly property real cy: height / 2
                    readonly property real level: Audio.muted ? 0 : Math.max(0, Math.min(1, Audio.volume))
                    readonly property real turn: -225 + 270 * level        // degrees (0: three o'clock)
                    opacity: Audio.muted ? 0.45 : 1
                    // the whole scale, faint
                    ShapePath {
                        strokeColor: Qt.rgba(0.21, 0.19, 0.16, 0.3); strokeWidth: 2.2 * bar.s
                        fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: knob.cx; centerY: knob.cy; radiusX: knob.r; radiusY: knob.r; startAngle: 135; sweepAngle: 270 }
                    }
                    // the turned part
                    ShapePath {
                        strokeColor: bar.ink; strokeWidth: 2.6 * bar.s
                        fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: knob.cx; centerY: knob.cy; radiusX: knob.r; radiusY: knob.r; startAngle: 135; sweepAngle: Math.max(0.01, 270 * knob.level) }
                    }
                    // the knob's face and its marker
                    ShapePath {
                        strokeColor: "transparent"; fillColor: bar.ink
                        PathAngleArc { centerX: knob.cx; centerY: knob.cy; radiusX: knob.r * 0.46; radiusY: knob.r * 0.46; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: "#f2ead8"; strokeWidth: 1.8 * bar.s; capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        startX: knob.cx; startY: knob.cy
                        PathLine {
                            x: knob.cx + Math.cos((135 + 270 * knob.level) * Math.PI / 180) * knob.r * 0.42
                            y: knob.cy + Math.sin((135 + 270 * knob.level) * Math.PI / 180) * knob.r * 0.42
                        }
                    }
                    // muted: struck through
                    ShapePath {
                        strokeColor: Audio.muted ? bar.ink : "transparent"; strokeWidth: 2.2 * bar.s; capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        startX: knob.width * 0.12; startY: knob.height * 0.88
                        PathLine { x: knob.width * 0.88; y: knob.height * 0.12 }
                    }
                }
                Divider { k: bar.s }

                // the battery: slim, filled as far as it is charged (green
                // while charging, rust when low), and its figure
                Row {
                    visible: Power.present
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * bar.s
                    Item {
                        id: batt
                        anchors.verticalCenter: parent.verticalCenter
                        width: 31 * bar.s; height: 14 * bar.s
                        readonly property color tone: Power.charging ? "#4f9b45" : Power.low ? bar.rust : bar.ink
                        Rectangle {
                            width: 28 * bar.s; height: parent.height; radius: 3.6 * bar.s
                            color: "transparent"; border.width: 2 * bar.s; border.color: bar.ink
                            Rectangle {
                                x: 3.2 * bar.s; y: 3.2 * bar.s
                                height: parent.height - 6.4 * bar.s; radius: 1.6 * bar.s
                                width: Math.max(height * 0.6, (parent.width - 6.4 * bar.s) * Power.percent / 100)
                                color: batt.tone
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                        Rectangle { x: 28.8 * bar.s; y: parent.height * 0.3; width: 2.2 * bar.s; height: parent.height * 0.4; radius: 1 * bar.s; color: bar.ink }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Power.percent + "%"
                        color: Power.low && !Power.charging ? bar.rust : bar.ink
                        opacity: 0.85
                        font.family: bar.figures
                        font.pixelSize: Math.round(17 * bar.s)
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -8 * bar.s
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.toggle("controls")
                onWheel: e => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
        Divider { k: bar.s }

        // ---- the date and the time: a click brings up the clock
        Item {
            width: when.width; height: parent.height
            Row {
                id: when
                height: parent.height
                spacing: 11 * bar.s
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1 * bar.s
                    text: Qt.formatDate(Clock.now, "ddd d MMM").toUpperCase()
                    color: bar.ink
                    opacity: 0.72
                    font.family: bar.figures
                    font.pixelSize: Math.round(16 * bar.s)
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2 * bar.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Clock.time
                    color: bar.ink
                    font.family: bar.figures
                    font.pixelSize: Math.round(24 * bar.s)
                    font.weight: Font.Bold
                    font.letterSpacing: 1 * bar.s
                    font.features: { "tnum": 1 }
                }
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -8 * bar.s
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.toggle("clock")
            }
        }
    }
    }
}
