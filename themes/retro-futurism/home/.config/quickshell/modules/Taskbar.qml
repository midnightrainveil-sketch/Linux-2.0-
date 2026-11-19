import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The taskbar: a chrome tube along the foot of the screen, four modules
// set in its groove (art/TaskbarEg.png).
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
    implicitHeight: Theme.barBottom
    exclusiveZone: Theme.barBottom - 4
    WlrLayershell.namespace: "retro-futurism-bar"
    color: "transparent"

    // the look, from the mock-up
    readonly property color cream: "#eadecc"
    readonly property color creamHi: "#f4ebdc"
    readonly property color creamLo: "#ddcfb9"
    readonly property color sage: "#808163"
    readonly property color sageHi: "#a9a88c"
    readonly property color sageLo: "#6c6d52"
    readonly property color rust: "#b2512f"
    readonly property color ink: "#35312a"
    readonly property color dotOn: "#706750"
    readonly property color dotOff: "#c3b49e"
    readonly property color paper: "#f6efdf"      // light lettering on the band
    readonly property color amber: "#ffb04c"
    readonly property string face: "Inter"

    readonly property int tubeH: 52
    readonly property int side: 14

    // ---- a soft shadow under the tube
    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: bar.side - index * 2; width: bar.width - 2 * bar.side + index * 4
            y: 9 + index * 1.5; height: bar.tubeH
            radius: height / 2
            color: "#000000"
            opacity: 0.07 - index * 0.012
        }
    }

    // ---- the chrome tube
    Rectangle {
        id: tube
        x: bar.side; y: 6
        width: bar.width - 2 * bar.side; height: bar.tubeH
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: "#fdfbf8" }
            GradientStop { position: 0.10; color: "#d6ccc2" }
            GradientStop { position: 0.22; color: "#948b7f" }
            GradientStop { position: 0.50; color: "#b9b2a6" }
            GradientStop { position: 0.80; color: "#d4d0ca" }
            GradientStop { position: 0.90; color: "#8e8984" }
            GradientStop { position: 1.00; color: "#5e5950" }
        }
        border.width: 1
        border.color: "#6f6a62"

        // glints along the top and the bottom of the tube
        Repeater {
            model: [[0.27, 0], [0.52, 0], [0.78, 0], [0.33, 1], [0.64, 1], [0.9, 1]]
            Rectangle {
                required property var modelData
                x: tube.width * modelData[0] - width / 2
                y: modelData[1] === 0 ? 2 : tube.height - 6
                width: 70; height: 4; radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00ffffff" }
                    GradientStop { position: 0.5; color: "#ccffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }
        }

        // the groove the modules sit in
        Rectangle {
            id: groove
            anchors.fill: parent
            anchors.margins: 5
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#4a453c" }
                GradientStop { position: 0.5; color: "#6d6752" }
                GradientStop { position: 1.0; color: "#857f6c" }
            }
            // the rust tip at the right end, as on the mock-up
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 4; height: parent.height - 18; radius: 2
                color: bar.rust; opacity: 0.85
            }
        }

        // ---- the modules
        Item {
            id: row
            anchors.fill: groove
            anchors.margins: 2
            readonly property int h: height

            // a cream plate with a slight top light
            component Plate: Rectangle {
                radius: 10
                border.width: 1
                border.color: "#c8b89e"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: bar.creamHi }
                    GradientStop { position: 0.55; color: bar.cream }
                    GradientStop { position: 1.0; color: bar.creamLo }
                }
            }
            component Sep: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 20; color: "#8e8471"; opacity: 0.8
            }

            // ======== the port: where the app cartridges go in
            Plate {
                id: port
                x: 6; width: 82; height: row.h
                readonly property bool lit: Panels.open === "launcher"

                // the insert mark over the slot, as on the Kasetto launcher
                Canvas {
                    x: slot.x + slot.width / 2 - 5; y: slot.y - 7
                    width: 10; height: 6
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        c.beginPath(); c.moveTo(0, 0); c.lineTo(10, 0); c.lineTo(5, 5); c.closePath();
                        c.fillStyle = bar.rust; c.fill();
                    }
                }
                // the slot: a wide, shallow mouth, gold contacts along its floor
                Rectangle {
                    id: slot
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    x: 9; width: 54; height: 15; radius: 3
                    color: "#1b1916"
                    border.width: 1
                    border.color: portMouse.containsMouse ? "#9c8a63" : "#8f8270"
                    // the lip shades the inside from above
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 1.5; radius: 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#070706" }
                            GradientStop { position: 1.0; color: "#2a2620" }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2.5
                        spacing: 2.4
                        Repeater {
                            model: 10
                            Rectangle {
                                width: 2.6; height: 5; radius: 0.6
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: port.lit ? "#ffe2a0" : "#d8b45e" }
                                    GradientStop { position: 1.0; color: "#8a6a2a" }
                                }
                            }
                        }
                    }
                }
                // the lamp: lit while the launcher is open
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: slot.x + slot.width + 6
                    width: 6; height: 6; radius: 3
                    color: port.lit ? bar.amber : (portMouse.containsMouse ? "#a57a3c" : "#6b5a40")
                    border.width: 1; border.color: "#3b2f20"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 16; height: 16; radius: 8
                        color: bar.amber
                        opacity: port.lit ? 0.28 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
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

            // ======== workspaces
            Plate {
                id: spaces
                anchors.left: port.right; anchors.leftMargin: 8
                width: Hypr.ids.length * 42 + 22; height: row.h

                Row {
                    anchors.centerIn: parent
                    Repeater {
                        model: Hypr.ids
                        Item {
                            id: cell
                            required property int modelData
                            readonly property bool active: modelData === Hypr.activeId
                            readonly property var st: Hypr.state[modelData] ?? ({ occupied: false, urgent: false })
                            width: 42; height: row.h
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                text: cell.modelData
                                color: bar.ink
                                opacity: cell.active || cellMouse.containsMouse ? 1 : 0.82
                                font.family: bar.face
                                font.pixelSize: 16
                                font.weight: cell.active ? Font.DemiBold : Font.Medium
                            }
                            // the mark under it: the red line for the one in
                            // view, else a dot (dark where windows are)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: row.h - 10
                                width: cell.active ? 22 : 5; height: cell.active ? 3 : 5
                                radius: height / 2
                                color: cell.active ? bar.rust
                                     : cell.st.urgent ? bar.rust
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
                }
                WheelHandler {
                    onWheel: e => Hypr.relativeWorkspace(e.angleDelta.y > 0 ? -1 : 1)
                }
            }

            // ======== the readouts, at the right end
            Item {
                id: readouts
                anchors.right: parent.right; anchors.rightMargin: 16
                width: 330; height: row.h

                // a plate with its left end cut on the slant
                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        const w = width, h = height, s = 14, r = 10;
                        c.beginPath();
                        c.moveTo(s, 0.5); c.lineTo(w - r, 0.5); c.arcTo(w - 0.5, 0.5, w - 0.5, r, r);
                        c.lineTo(w - 0.5, h - r); c.arcTo(w - 0.5, h - 0.5, w - r, h - 0.5, r);
                        c.lineTo(3, h - 0.5); c.closePath();
                        const g = c.createLinearGradient(0, 0, 0, h);
                        g.addColorStop(0, bar.creamHi); g.addColorStop(0.55, bar.cream); g.addColorStop(1, bar.creamLo);
                        c.fillStyle = g; c.fill();
                        c.strokeStyle = "#c8b89e"; c.lineWidth = 1; c.stroke();
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 18
                    spacing: 18

                    // Wi-Fi: three arcs and a dot, lit to the signal
                    Canvas {
                        id: wifi
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 20
                        readonly property int level: !Net.online ? 0 : Net.wired ? 3 : Math.max(1, Math.ceil(Net.signal * 3))
                        onLevelChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset();
                            const cx = width / 2, cy = height - 2;
                            c.lineCap = "round"; c.lineWidth = 2.4;
                            for (let i = 1; i <= 3; i++) {
                                c.strokeStyle = bar.ink;
                                c.globalAlpha = i <= level ? 1 : 0.22;
                                c.beginPath(); c.arc(cx, cy, 4 + i * 4.6, Math.PI * 1.25, Math.PI * 1.75); c.stroke();
                            }
                            c.globalAlpha = level > 0 ? 1 : 0.4;
                            c.fillStyle = bar.ink; c.beginPath(); c.arc(cx, cy - 1, 2.2, 0, Math.PI * 2); c.fill();
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([Settings.terminal, "-e", "nmtui"])
                        }
                    }
                    Sep {}
                    // volume: the speaker and as many waves as it is loud
                    Canvas {
                        id: vol
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 20
                        readonly property int waves: Audio.muted ? -1 : Audio.volume <= 0.01 ? 0 : Audio.volume < 0.4 ? 1 : 2
                        onWavesChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset();
                            c.fillStyle = bar.ink; c.strokeStyle = bar.ink;
                            c.beginPath();
                            c.moveTo(2, 7); c.lineTo(6, 7); c.lineTo(11, 2.5); c.lineTo(11, 17.5); c.lineTo(6, 13); c.lineTo(2, 13);
                            c.closePath(); c.fill();
                            c.lineWidth = 2.2; c.lineCap = "round";
                            if (waves < 0) {
                                c.beginPath(); c.moveTo(15, 6.5); c.lineTo(22, 13.5); c.moveTo(22, 6.5); c.lineTo(15, 13.5); c.stroke();
                            }
                            for (let i = 1; i <= waves; i++) {
                                c.beginPath(); c.arc(11, 10, 3.5 + i * 4, -Math.PI * 0.3, Math.PI * 0.3); c.stroke();
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Audio.toggleMute()
                            onWheel: e => Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
                        }
                    }
                    Sep {}
                    // battery: four cells, a bolt while charging
                    Item {
                        id: batt
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 18
                        visible: Power.present
                        readonly property int cells: Math.max(Power.percent > 0 ? 1 : 0, Math.ceil(Power.percent / 25))
                        Rectangle {
                            width: 32; height: 18; radius: 3
                            color: "transparent"; border.width: 2; border.color: Power.low ? bar.rust : bar.ink
                            Row {
                                x: 4; y: 4; spacing: 2
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        width: 4.6; height: 10; radius: 0.5
                                        color: Power.low ? bar.rust : bar.ink
                                        opacity: index < batt.cells ? 1 : 0.15
                                    }
                                }
                            }
                        }
                        Rectangle { x: 32; y: 6; width: 3; height: 6; radius: 1; color: Power.low ? bar.rust : bar.ink }
                        Canvas {
                            // the charging bolt, amber, edged in ink
                            x: 6; y: -2; width: 20; height: 22
                            visible: Power.charging
                            onPaint: {
                                const c = getContext("2d"); c.reset();
                                c.beginPath();
                                c.moveTo(11.5, 1); c.lineTo(4, 12.5); c.lineTo(9.5, 12.5);
                                c.lineTo(8, 21); c.lineTo(16, 9); c.lineTo(10.5, 9); c.closePath();
                                c.fillStyle = bar.amber; c.fill();
                                c.lineWidth = 1.4; c.strokeStyle = bar.ink; c.stroke();
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = Power.profiles, i = p.indexOf(Power.profile);
                                Power.setProfile(p[(i + 1) % p.length]);
                            }
                        }
                    }
                    Sep { visible: Power.present }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Clock.time
                        color: bar.ink
                        font.family: bar.face
                        font.pixelSize: 19
                        font.weight: Font.Medium
                        font.letterSpacing: 1.2
                        font.features: { "tnum": 1 }
                    }
                }
            }

            // ======== the band: the window in use, CASSETTE OS, the Arch logo
            Item {
                id: band
                anchors.left: spaces.right; anchors.leftMargin: 8
                anchors.right: readouts.left; anchors.rightMargin: -6
                height: row.h

                // the sage plate, both ends cut on the slant
                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset();
                        const w = width, h = height, s = 14;
                        c.beginPath();
                        c.moveTo(s, 0.5); c.lineTo(w - 3, 0.5); c.lineTo(w - s, h - 0.5); c.lineTo(3, h - 0.5); c.closePath();
                        const g = c.createLinearGradient(0, 0, 0, h);
                        g.addColorStop(0, bar.sageHi); g.addColorStop(0.12, bar.sage);
                        g.addColorStop(0.85, bar.sageLo); g.addColorStop(1, "#5f6048");
                        c.fillStyle = g; c.fill();
                        c.strokeStyle = "#5a5b43"; c.lineWidth = 1; c.stroke();
                    }
                }

                // right: /// CASSETTE OS | Arch
                Row {
                    id: brand
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right; anchors.rightMargin: 26
                    spacing: 14
                    // the three slashes
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 5; height: 16; radius: 1
                                color: bar.paper; opacity: 0.85
                                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.45, 0, 7, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                            }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CASSETTE OS"
                        color: bar.paper
                        font.family: bar.face
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.letterSpacing: 4.2
                        style: Text.Raised; styleColor: "#55563f"
                    }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1.5; height: 20; color: bar.paper; opacity: 0.7 }
                    ArchLogo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 21; height: 21
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

                // left: the window in use, then the red line up to the brand
                Text {
                    id: title
                    anchors.verticalCenter: parent.verticalCenter
                    x: 30
                    width: Math.min(implicitWidth, brand.x - x - 60)
                    text: Hypr.activeTitle.toUpperCase()
                    elide: Text.ElideRight
                    color: "#2a2b20"
                    font.family: bar.face
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: title.text === "" ? 30 : title.x + title.width + 16
                    width: brand.x - x - 24
                    height: 2; radius: 1
                    color: bar.rust
                }
            }
        }
    }
}
