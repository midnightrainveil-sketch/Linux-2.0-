import QtQuick
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// The turntable, seen from straight above as it stands on the desk: an oak
// plinth, a record whose label is typed like a herbarium label, and a brass
// tone arm. The whole record is the track that is playing: the arm's place
// across it is how far through that track you are.
//
//   click the record, the cue lever    pause / play
//   turn the record by hand            wind back (anticlockwise) or on, as you turn
//   drag the arm onto the record       play from there; back to its rest: pause
//   scroll on the record               wind on / back 10 s
//   the brass buttons                  previous, pause / play, next
//   the line on the title card         where in the song; drag along it
//   scroll on the knob                 volume
Item {
    id: deck

    width: 570
    height: 570

    // what is on the platter
    property var album: null            // {name, artist, year, tracks: [{length}]}
    property string labelTitle: ""
    property string labelArtist: ""
    property string labelNo: ""
    property string nowPlaying: ""
    property bool spinning: false
    property bool shown: true           // the phonograph is open (a closed layer keeps visible: true)
    property bool onRecord: false       // the arm is down on a record (playing or paused)
    property bool lifted: false         // paused: the arm hangs just above the groove
    property real progress: 0           // 0..1 of the whole record
    property int volume: 100
    property bool volumeShown: true
    property string cover: ""           // the playing track's picture: on the label
    property real trackProgress: 0      // 0..1 of the song playing
    property string trackTimes: ""      // "0:21 / 3:15"

    signal toggled()
    signal needleDropped(real f)        // 0..1 across the record
    signal armRested()
    signal wound(real seconds)
    signal volumeAsked(int v)
    signal previousAsked()
    signal nextAsked()
    signal scrubbed(real f)             // 0..1 of the song

    // ---------------------------------------------------------------- geometry
    // The deck is the photograph in assets/phonograph (tools/import_objects.py)
    // when it is there, else drawn. The places are measured on the photograph:
    // the spindle, the felt's edge, the arm's mount, the knob.
    readonly property bool art: plinthImg.status === Image.Ready && armImg.status === Image.Ready
    readonly property point centre: art ? Qt.point(250.9, 264.5) : Qt.point(250, 290)
    readonly property real recordR: art ? 204 : 210
    readonly property real outerGroove: art ? 198 : 204
    readonly property real innerGroove: 80
    readonly property point pivot: art ? Qt.point(496.8, 83.2) : Qt.point(490, 92)
    readonly property real armLength: 310
    readonly property real restAngle: 90

    // the arm's angle (degrees, 0 = pointing right) that puts the stylus at
    // radius r from the spindle
    function angleFor(r: real): real {
        const dx = centre.x - pivot.x, dy = centre.y - pivot.y;
        const d = Math.hypot(dx, dy), L = armLength;
        const phi = Math.acos(Math.max(-1, Math.min(1, (L * L + d * d - r * r) / (2 * L * d))));
        return (Math.atan2(dy, dx) - phi) * 180 / Math.PI;
    }
    function radiusAt(angle: real): real {
        const a = angle * Math.PI / 180;
        return Math.hypot(pivot.x + armLength * Math.cos(a) - centre.x, pivot.y + armLength * Math.sin(a) - centre.y);
    }
    readonly property real startAngle: angleFor(outerGroove)
    readonly property real endAngle: angleFor(innerGroove)

    readonly property color wood: Theme.night > 0.5 ? "#101a2b" : "#3a2f27"
    readonly property color brass: Theme.night > 0.5 ? "#7d8aa1" : "#a68a5b"
    readonly property color vinyl: Theme.night > 0.5 ? "#0b1220" : "#151416"

    // ---------------------------------------------------------------- the plinth
    Image {
        id: plinthImg
        anchors.fill: parent
        source: Qt.resolvedUrl("../../assets/phonograph/turntable.jpg")
        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
        smooth: true
        visible: false
    }
    DropShadow {
        anchors.fill: plinth
        source: deck.art ? plinthImg : plinth
        radius: 24
        cached: true                  // it never changes: blurred once, not every frame
        samples: 33
        verticalOffset: 10
        color: Qt.rgba(0, 0, 0, 0.42)
    }
    Canvas {
        id: plinth
        anchors.fill: parent
        visible: !deck.art
        readonly property string woodTile: Qt.resolvedUrl("../../assets/drawer/wood.jpg")
        readonly property real nightTint: Theme.night
        readonly property color tone: deck.wood
        onToneChanged: requestPaint()
        onNightTintChanged: requestPaint()
        onImageLoaded: requestPaint()
        Component.onCompleted: loadImage(woodTile)
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const w = width, h = height, r = 14;
            const shape = (inset, rad) => {
                g.beginPath();
                g.roundedRect(inset, inset, w - 2 * inset, h - 2 * inset, rad, rad);
            };
            shape(0, r);
            if (isImageLoaded(woodTile)) {
                g.fillStyle = g.createPattern(woodTile, "repeat");
                g.fill();
                g.fillStyle = Qt.rgba(0.06, 0.10, 0.17, 0.72 * nightTint);
                g.fill();
            } else {
                g.fillStyle = String(tone);
                g.fill();
            }
            // lit from the top left: a soft fall-off across the top
            const light = g.createLinearGradient(0, 0, w, h);
            light.addColorStop(0, Qt.rgba(1, 0.95, 0.85, 0.10 * (1 - 0.6 * nightTint)));
            light.addColorStop(0.5, Qt.rgba(0, 0, 0, 0));
            light.addColorStop(1, Qt.rgba(0, 0, 0, 0.22));
            g.fillStyle = light;
            g.fill();
            // the bevelled edge: light along the top and left, dark below
            g.lineWidth = 2;
            g.strokeStyle = Qt.rgba(1, 0.94, 0.84, 0.20 * (1 - 0.5 * nightTint));
            shape(2, r - 2);
            g.stroke();
            g.lineWidth = 1;
            g.strokeStyle = Qt.rgba(0, 0, 0, 0.5);
            shape(0.5, r);
            g.stroke();
            // the recessed top panel the platter sits in
            g.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
            g.lineWidth = 1.5;
            shape(14, 8);
            g.stroke();
            g.strokeStyle = Qt.rgba(1, 0.94, 0.84, 0.08);
            g.lineWidth = 1;
            shape(15.5, 7);
            g.stroke();
        }
    }

    // by night the photograph goes blue like the rest of the desk
    Colorize {
        anchors.fill: parent
        source: plinthImg
        visible: deck.art && Theme.night > 0.01
        opacity: Theme.night
        hue: 0.6; saturation: 0.35; lightness: -0.12
    }
    // the photograph's brass plate, engraved
    Column {
        visible: deck.art
        x: 22.7; y: 31
        width: 85
        spacing: 3
        Repeater {
            model: ["SOUND ARCHIVE", "33⅓ R.P.M."]
            Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                font.family: Theme.typewriter
                font.pixelSize: 7
                font.letterSpacing: 0.5
                font.bold: true
                color: Qt.rgba(0.12, 0.08, 0.04, 0.7)
                style: Text.Raised
                styleColor: Qt.rgba(1, 0.9, 0.7, 0.25)
            }
        }
    }

    // a little brass plate, engraved
    Rectangle {
        visible: !deck.art
        x: 30; y: 28
        width: plateText.implicitWidth + 22
        height: 24
        radius: 2
        color: deck.brass
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.4)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(deck.brass, 1.18) }
            GradientStop { position: 1; color: Qt.darker(deck.brass, 1.15) }
        }
        Text {
            id: plateText
            anchors.centerIn: parent
            text: "SOUND ARCHIVE  ·  33⅓"
            font.family: Theme.typewriter
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Qt.rgba(0.12, 0.09, 0.05, 0.75)
            style: Text.Raised
            styleColor: Qt.rgba(1, 1, 1, 0.25)
        }
    }

    // ---------------------------------------------------------------- the platter
    Item {
        id: platter
        x: deck.centre.x - width / 2
        y: deck.centre.y - height / 2
        width: 2 * (deck.recordR + 13)
        height: width

        // the turned steel rim, with its strobe dots (it turns, so the dots run)
        Canvas {
            id: rim
            anchors.fill: parent
            visible: !deck.art
            rotation: record.rotation
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const c = width / 2;
                const grad = g.createRadialGradient(c * 0.8, c * 0.7, 0, c, c, c);
                grad.addColorStop(0, "#9a9a98");
                grad.addColorStop(0.85, "#6d6c6a");
                grad.addColorStop(1, "#3e3d3c");
                g.fillStyle = grad;
                g.beginPath(); g.arc(c, c, c, 0, Math.PI * 2); g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.5);
                g.lineWidth = 1;
                g.stroke();
                g.fillStyle = Qt.rgba(0.1, 0.1, 0.1, 0.55);
                for (let i = 0; i < 90; i++) {
                    const a = i / 90 * Math.PI * 2;
                    g.fillRect(c + Math.cos(a) * (c - 6) - 1.2, c + Math.sin(a) * (c - 6) - 1.2, 2.4, 2.4);
                }
            }
        }
        // night: the steel goes blue like everything else
        Rectangle {
            visible: !deck.art
            anchors.fill: parent
            radius: width / 2
            color: "#1c2f4d"
            opacity: 0.45 * Theme.night
        }

        // the record
        Item {
            id: record
            anchors.centerIn: parent
            width: 2 * deck.recordR
            height: width
            // a new record is set down: it drops the last few millimetres
            property string onIt: deck.labelTitle + "|" + deck.labelArtist
            onOnItChanged: if (onIt !== "|") setDown.restart()
            SequentialAnimation {
                id: setDown
                ParallelAnimation {
                    NumberAnimation { target: record; property: "scale"; from: 1.06; to: 1; duration: Theme.dur(380); easing.type: Easing.OutBounce }
                    NumberAnimation { target: record; property: "opacity"; from: 0.6; to: 1; duration: Theme.dur(200) }
                }
            }
            visible: deck.album !== null || deck.labelTitle !== ""

            Canvas {
                id: grooves
                anchors.fill: parent
                readonly property color base: deck.vinyl
                readonly property string key: String(base) + deck.recordR
                onKeyChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    const c = width / 2, R = deck.recordR;
                    g.fillStyle = String(base);
                    g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.fill();
                    // the grooves: fine rings, a little lighter and darker
                    const rnd = Rand.make(77);
                    for (let r = deck.innerGroove; r < deck.outerGroove; r += 1.6) {
                        g.strokeStyle = rnd() < 0.5 ? Qt.rgba(1, 1, 1, 0.025 + rnd() * 0.03) : Qt.rgba(0, 0, 0, 0.25);
                        g.lineWidth = 0.8;
                        g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.stroke();
                    }
                    // the lead-in and run-out, and the rolled edge
                    g.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
                    g.lineWidth = 3;
                    g.beginPath(); g.arc(c, c, deck.outerGroove + 3, 0, Math.PI * 2); g.stroke();
                    g.beginPath(); g.arc(c, c, deck.innerGroove - 5, 0, Math.PI * 2); g.stroke();
                    g.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
                    g.lineWidth = 1;
                    g.beginPath(); g.arc(c, c, R - 1, 0, Math.PI * 2); g.stroke();
                }
            }

            // the label, typed like a herbarium label
            Canvas {
                id: label
                readonly property real r: 66
                x: parent.width / 2 - r
                y: parent.height / 2 - r
                width: 2 * r
                height: 2 * r
                readonly property color paper: Theme.paperRaised
                readonly property color ink: Theme.graphite
                readonly property color faint: Theme.faded
                readonly property color mark: Theme.madder
                readonly property string key: [deck.labelTitle, deck.labelArtist, deck.labelNo, paper, ink].join("|")
                onKeyChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    const c = r;
                    g.fillStyle = String(paper);
                    g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.fill();
                    g.strokeStyle = String(ink);
                    g.globalAlpha = 0.55;
                    g.lineWidth = 1.2;
                    g.beginPath(); g.arc(c, c, r - 6, 0, Math.PI * 2); g.stroke();
                    g.lineWidth = 0.6;
                    g.beginPath(); g.arc(c, c, r - 9, 0, Math.PI * 2); g.stroke();
                    g.globalAlpha = 1;
                    g.fillStyle = String(ink);
                    g.textAlign = "center";
                    g.textBaseline = "middle";
                    // around the top
                    g.font = "bold 7px '" + Theme.typewriter + "'";
                    const ring = "PHONOGRAPHIC COLLECTION";
                    const spread = 1.9;
                    for (let i = 0; i < ring.length; i++) {
                        const a = -Math.PI / 2 - spread / 2 + spread * i / (ring.length - 1);
                        g.save();
                        g.translate(c + Math.cos(a) * (r - 16), c + Math.sin(a) * (r - 16));
                        g.rotate(a + Math.PI / 2);
                        g.fillText(ring[i], 0, 0);
                        g.restore();
                    }
                    // the title, on two lines if it must
                    const words = deck.labelTitle.split(/\s+/);
                    let lines = [deck.labelTitle];
                    g.font = "bold 10px '" + Theme.typewriter + "'";
                    if (g.measureText(deck.labelTitle).width > 92 && words.length > 1) {
                        let best = 1, bestW = 1e9;
                        for (let k = 1; k < words.length; k++) {
                            const a = words.slice(0, k).join(" "), b = words.slice(k).join(" ");
                            const m = Math.max(g.measureText(a).width, g.measureText(b).width);
                            if (m < bestW) { bestW = m; best = k; }
                        }
                        lines = [words.slice(0, best).join(" "), words.slice(best).join(" ")];
                    }
                    const fit = s => { let t = s; while (t.length > 3 && g.measureText(t).width > 96) t = t.slice(0, -2); return t === s ? s : t + "…"; };
                    lines.forEach((l, i) => g.fillText(fit(l), c, c - 18 + i * 12 - (lines.length - 1) * 4));
                    g.font = "8px '" + Theme.typewriter + "'";
                    g.fillStyle = String(faint);
                    g.fillText(fit(deck.labelArtist), c, c + 20);
                    // the spindle hole's neighbours: catalogue number, a sprig
                    g.fillText(deck.labelNo, c + 30, c + 2);
                    g.strokeStyle = String(mark);
                    g.globalAlpha = 0.7;
                    g.lineWidth = 0.9;
                    g.beginPath();
                    g.moveTo(c - 34, c + 10); g.quadraticCurveTo(c - 31, c, c - 33, c - 8);
                    for (let i = 0; i < 4; i++) {
                        const yy = c + 7 - i * 4;
                        g.moveTo(c - 32.5, yy); g.lineTo(c - 29, yy - 3);
                        g.moveTo(c - 33, yy); g.lineTo(c - 36.5, yy - 2.5);
                    }
                    g.stroke();
                    g.globalAlpha = 1;
                    // the rule under the title
                    g.strokeStyle = String(ink);
                    g.globalAlpha = 0.4;
                    g.lineWidth = 0.6;
                    g.beginPath(); g.moveTo(c - 26, c + 11); g.lineTo(c + 26, c + 11); g.stroke();
                    g.globalAlpha = 1;
                }
            }
            Grain {
                anchors.fill: label
                strength: 1.4
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle { width: label.width; height: label.height; radius: width / 2 }
                }
            }
            // the track's own picture printed on the label, when it has one
            Item {
                id: labelArt
                anchors.fill: label
                visible: coverImg.status === Image.Ready
                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: deck.cover === "" ? "" : (deck.cover.startsWith("/") ? "file://" + deck.cover : deck.cover)
                    sourceSize: Qt.size(264, 264)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    visible: false
                }
                OpacityMask {
                    anchors.fill: parent
                    source: coverImg
                    maskSource: Rectangle { width: labelArt.width; height: labelArt.height; radius: width / 2 }
                }
                // printed on paper: a little of the colour let down, the
                // paper's grain over it, a pressed ring at the edge
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.paperRaised
                    opacity: 0.12
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Qt.rgba(0, 0, 0, 0.35)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 14; radius: 7
                    color: Qt.rgba(0, 0, 0, 0.28)
                }
            }
        }

        // the light lying on the record: it does not turn with it, which is
        // what makes it look like it turns
        Canvas {
            anchors.centerIn: parent
            width: record.width
            height: record.height
            visible: record.visible
            onWidthChanged: requestPaint()
            opacity: 1 - 0.5 * Theme.night
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const c = width / 2;
                const sheen = g.createConicalGradient(c, c, -Math.PI / 4);
                sheen.addColorStop(0.00, Qt.rgba(1, 1, 1, 0.0));
                sheen.addColorStop(0.06, Qt.rgba(1, 1, 1, 0.10));
                sheen.addColorStop(0.13, Qt.rgba(1, 1, 1, 0.0));
                sheen.addColorStop(0.50, Qt.rgba(1, 1, 1, 0.0));
                sheen.addColorStop(0.56, Qt.rgba(1, 1, 1, 0.07));
                sheen.addColorStop(0.63, Qt.rgba(1, 1, 1, 0.0));
                sheen.addColorStop(1.00, Qt.rgba(1, 1, 1, 0.0));
                g.fillStyle = sheen;
                g.beginPath();
                g.arc(c, c, deck.recordR - 2, 0, Math.PI * 2);
                g.arc(c, c, 68, 0, Math.PI * 2, true);
                g.fill();
            }
        }

        // the spindle
        Rectangle {
            anchors.centerIn: parent
            width: 9; height: 9; radius: 4.5
            gradient: Gradient {
                GradientStop { position: 0; color: "#d8d6d0" }
                GradientStop { position: 1; color: "#6c6a66" }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
        }

        // the felt mat, when no record is on
        Rectangle {
            anchors.centerIn: parent
            visible: !record.visible && !deck.art
            width: 2 * deck.recordR - 6
            height: width
            radius: width / 2
            color: Theme.night > 0.5 ? "#1a2a3c" : "#2f3a2e"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.4)
            Grain { anchors.fill: parent; strength: 2; layer.enabled: true }
            Rectangle {
                anchors.centerIn: parent
                width: 9; height: 9; radius: 4.5
                color: "#a8a6a0"
            }
        }

        // a click: pause / play. Held and turned: the record goes round
        // under the hand and the music winds with it, one turn 8 s
        MouseArea {
            id: hand
            anchors.fill: parent
            cursorShape: deck.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            property real lastAngle: 0
            property real moved: 0
            function angleAt(m) { return Math.atan2(m.y - height / 2, m.x - width / 2) * 180 / Math.PI; }
            onPressed: m => { lastAngle = angleAt(m); moved = 0; }
            onPositionChanged: m => {
                if (!pressed) return;
                let d = angleAt(m) - lastAngle;
                if (d > 180) d -= 360;
                if (d < -180) d += 360;
                lastAngle = angleAt(m);
                moved += Math.abs(d);
                if (moved < 4) return;
                deck.held = true;
                record.rotation = (record.rotation + d + 360) % 360;
                deck.windOwed += d / 360 * 8;
                if (!windTick.running) windTick.start();
            }
            onReleased: {
                if (deck.held) { windTick.stop(); deck.payWind(); deck.held = false; }
                else deck.toggled();
            }
            onWheel: wheel => deck.wound(wheel.angleDelta.y > 0 ? -10 : 10)
        }
    }
    property bool held: false
    property real windOwed: 0           // seconds turned by hand, not yet sent
    function payWind(): void {
        if (Math.abs(windOwed) >= 0.25) { deck.wound(windOwed); windOwed = 0; }
    }
    Timer { id: windTick; interval: 160; repeat: true; onTriggered: deck.payWind() }

    // ---------------------------------------------------------------- turning
    // 33⅓ turns a minute; it runs up to speed and coasts down
    property real speed: spinning ? 1 : 0
    Behavior on speed { NumberAnimation { duration: Theme.dur(1100); easing.type: Easing.InOutQuad } }
    FrameAnimation {
        running: deck.speed > 0.001 && deck.visible && deck.shown && !deck.held
        onTriggered: record.rotation = (record.rotation + frameTime * 200 * deck.speed) % 360
    }

    // ---------------------------------------------------------------- the arm
    // its rest, and the cue lever
    Rectangle {
        visible: !deck.art
        x: deck.pivot.x - 7
        y: deck.pivot.y + deck.armLength - 92
        width: 14; height: 26; radius: 4
        color: "#2a2826"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4; width: 8; height: 6; radius: 3; color: "#4a4744" }
    }
    Item {
        id: lever
        visible: !deck.art
        x: deck.pivot.x + 48
        y: deck.pivot.y + 70
        width: 20; height: 60
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 34; width: 18; height: 18; radius: 9; color: Qt.darker(deck.brass, 1.3); border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5) }
        Rectangle {
            id: leverHandle
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 6; height: 42; radius: 3
            transformOrigin: Item.Bottom
            rotation: deck.lifted || !deck.onRecord ? -28 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.lighter(deck.brass, 1.25) }
                GradientStop { position: 1; color: Qt.darker(deck.brass, 1.3) }
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: deck.toggled()
        }
    }

    // the arm's base, under it
    Canvas {
        visible: !deck.art
        x: deck.pivot.x - 38
        y: deck.pivot.y - 38
        width: 76; height: 76
        readonly property color b: deck.brass
        onBChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const c = 38;
            let grad = g.createRadialGradient(c - 10, c - 12, 2, c, c, 36);
            grad.addColorStop(0, String(Qt.lighter(b, 1.35)));
            grad.addColorStop(0.7, String(b));
            grad.addColorStop(1, String(Qt.darker(b, 1.5)));
            g.fillStyle = grad;
            g.beginPath(); g.arc(c, c, 34, 0, Math.PI * 2); g.fill();
            g.strokeStyle = Qt.rgba(0, 0, 0, 0.45); g.lineWidth = 1; g.stroke();
            g.beginPath(); g.arc(c, c, 24, 0, Math.PI * 2); g.stroke();
            g.strokeStyle = Qt.rgba(1, 1, 1, 0.25);
            g.beginPath(); g.arc(c, c, 23, Math.PI, Math.PI * 1.6); g.stroke();
        }
    }

    // where the arm is: at its rest, or over the groove it is playing
    property bool dragging: false
    property real dragAngle: restAngle
    readonly property real playAngle: startAngle + (endAngle - startAngle) * Math.max(0, Math.min(1, progress))
    // put on its rest by hand: it stays there (paused) until the music goes on
    property bool parked: false
    onLiftedChanged: if (!lifted) parked = false
    onOnRecordChanged: { if (!onRecord) parked = false; go(true); }
    // let down on the record by hand: it stays where it was put while the
    // player finds that place, instead of swinging back to where the music
    // was and then across again
    property bool holding: false
    property real holdAngle: restAngle
    Timer { id: holdLimit; interval: 3000; onTriggered: deck.holding = false }
    onPlayAngleChanged: {
        if (holding && Math.abs(playAngle - holdAngle) < 2.5) holding = false;
        go(false);
    }
    readonly property real armAngle: dragging ? dragAngle
        : holding ? holdAngle
        : (onRecord && !parked ? playAngle : restAngle)

    // Moving the arm: small steps (the music going on) it creeps; anything
    // further is a cue: lift, swing across, lower into the groove. A jump in
    // where the player says it is (a seek, a new track, reported in steps)
    // must hold for a moment first, so a passing hiccup does not lift it.
    property real cueTo: restAngle
    property int cueTime: 400
    Component.onCompleted: arm.rotation = armAngle
    onDragAngleChanged: if (dragging) arm.rotation = dragAngle
    onDraggingChanged: go(true)
    onParkedChanged: go(true)
    onHoldingChanged: go(true)
    function go(now: bool): void {
        if (dragging) { cue.stop(); creep.stop(); settle.stop(); arm.rotation = armAngle; return; }
        const d = Math.abs(armAngle - arm.rotation);
        if (cue.running) { cueTo = armAngle; return; }
        if (d < 1.5) { settle.stop(); creep.to = armAngle; creep.restart(); return; }
        if (!now) { if (!settle.running) settle.restart(); return; }
        settle.stop();
        creep.stop();
        cueTo = armAngle;
        cueTime = Theme.dur(Math.round(260 + d * 22));
        cue.restart();
    }
    Timer { id: settle; interval: 700; onTriggered: deck.go(true) }
    NumberAnimation { id: creep; target: arm; property: "rotation"; duration: 450 }
    SequentialAnimation {
        id: cue
        NumberAnimation { target: arm; property: "cueLift"; to: 1; duration: Theme.dur(170); easing.type: Easing.OutCubic }
        NumberAnimation { target: arm; property: "rotation"; to: deck.cueTo; duration: deck.cueTime; easing.type: Easing.InOutCubic }
        // let down gently, with the faintest bounce on the record
        NumberAnimation { target: arm; property: "cueLift"; to: 0; duration: Theme.dur(300); easing.type: Easing.OutBack; easing.overshoot: 2 }
        ScriptAction { script: if (Math.abs(arm.rotation - deck.armAngle) > 0.01) { creep.to = deck.armAngle; creep.restart(); } }
    }

    Item {
        id: arm
        x: deck.pivot.x
        y: deck.pivot.y
        width: 0; height: 0
        // lifted (paused, at rest, or on its way across) it rides a little
        // higher: nearer, with a longer shadow
        readonly property real raised: deck.lifted || !deck.onRecord || deck.dragging ? 1 : 0
        property real cueLift: 0
        property real lift: Math.max(raised, cueLift)
        scale: 1 + 0.025 * lift
        Behavior on lift { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }

        // the photographed arm: pivot (85.6, 44.7) on the 447 x 112 picture,
        // its stylus 1.65° below the line of the tube
        Item {
            id: armArt
            visible: deck.art
            rotation: -1.65
            Image {
                id: armImg
                x: -85.6
                y: -44.7
                width: 447
                height: 112
                source: Qt.resolvedUrl("../../assets/phonograph/tonearm.png")
                sourceSize: Qt.size(894, 224)
                smooth: true
                visible: false
            }
            DropShadow {
                anchors.fill: armImg
                source: armImg
                radius: 6 + 8 * arm.lift
                samples: 21
                horizontalOffset: 3 + 7 * arm.lift
                verticalOffset: 4 + 10 * arm.lift
                color: Qt.rgba(0, 0, 0, 0.5 - 0.15 * arm.lift)
            }
            Image {
                anchors.fill: armImg
                source: armImg.source
                sourceSize: armImg.sourceSize
                smooth: true
            }
            Colorize {
                anchors.fill: armImg
                source: armImg
                visible: Theme.night > 0.01
                opacity: Theme.night
                hue: 0.6; saturation: 0.2; lightness: 0.0
            }
        }

        DropShadow {
            visible: !deck.art
            anchors.fill: armBody
            source: armBody
            radius: 6 + 6 * arm.lift
            samples: 17
            horizontalOffset: 3 + 6 * arm.lift
            verticalOffset: 4 + 8 * arm.lift
            color: Qt.rgba(0, 0, 0, 0.5 - 0.15 * arm.lift)
        }
        Canvas {
            id: armBody
            visible: !deck.art
            readonly property real len: deck.armLength
            x: -84
            y: -30
            width: len + 120
            height: 60
            readonly property color b: deck.brass
            onBChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const px = 84, py = 30, L = armBody.len;
                // the counterweight
                let grad = g.createLinearGradient(0, 16, 0, 44);
                grad.addColorStop(0, "#77746f"); grad.addColorStop(0.45, "#c9c6bf"); grad.addColorStop(1, "#3d3b38");
                g.fillStyle = grad;
                g.beginPath(); g.roundedRect(6, 15, 44, 30, 5, 5); g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.5); g.lineWidth = 1; g.stroke();
                g.fillStyle = Qt.rgba(0, 0, 0, 0.25);
                for (let i = 0; i < 6; i++) g.fillRect(12 + i * 6, 15, 1, 30);
                // the stub back to the pivot
                grad = g.createLinearGradient(0, py - 4, 0, py + 4);
                grad.addColorStop(0, "#d9d6cf"); grad.addColorStop(1, "#5e5b57");
                g.fillStyle = grad;
                g.fillRect(48, py - 3.5, px - 48, 7);
                // the pivot's gimbal
                grad = g.createRadialGradient(px - 4, py - 5, 1, px, py, 14);
                grad.addColorStop(0, String(Qt.lighter(b, 1.4))); grad.addColorStop(1, String(Qt.darker(b, 1.4)));
                g.fillStyle = grad;
                g.beginPath(); g.arc(px, py, 13, 0, Math.PI * 2); g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.5); g.stroke();
                // the tube: brass, lit along its top
                grad = g.createLinearGradient(0, py - 4, 0, py + 4);
                grad.addColorStop(0, String(Qt.lighter(b, 1.5)));
                grad.addColorStop(0.5, String(b));
                grad.addColorStop(1, String(Qt.darker(b, 1.6)));
                g.fillStyle = grad;
                g.beginPath();
                g.moveTo(px, py - 4); g.lineTo(px + L - 46, py - 3); g.lineTo(px + L - 46, py + 3); g.lineTo(px, py + 4);
                g.closePath(); g.fill();
                // the headshell, angled in, with its finger lift
                g.save();
                g.translate(px + L - 46, py);
                g.rotate(0.38);
                g.fillStyle = "#26231f";
                g.beginPath(); g.roundedRect(-4, -9, 52, 18, 3, 3); g.fill();
                g.strokeStyle = String(Qt.lighter(b, 1.1)); g.lineWidth = 1; g.stroke();
                g.strokeStyle = String(b); g.lineWidth = 3;
                g.beginPath(); g.moveTo(14, -9); g.quadraticCurveTo(18, -20, 30, -20); g.stroke();
                // the stylus, at the tip
                g.fillStyle = "#c9c6bf";
                g.beginPath(); g.arc(40, 0, 2.2, 0, Math.PI * 2); g.fill();
                g.restore();
            }

        }
        // take the arm by its headshell
        MouseArea {
            x: deck.armLength - 60
            y: -30
            width: 90
            height: 60
            cursorShape: deck.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            onPressed: { deck.dragAngle = deck.armAngle; deck.dragging = true; }
            onPositionChanged: mouse => {
                if (!deck.dragging) return;
                const p = mapToItem(deck, mouse.x, mouse.y);
                let a = Math.atan2(p.y - deck.pivot.y, p.x - deck.pivot.x) * 180 / Math.PI;
                deck.dragAngle = Math.max(deck.restAngle, Math.min(deck.endAngle, a));
            }
            onReleased: {
                const a = deck.dragAngle;
                if (a < deck.startAngle - 4) {
                    deck.parked = true;
                    deck.dragging = false;
                    deck.armRested();
                    return;
                }
                const r = deck.radiusAt(Math.max(a, deck.startAngle));
                const f = Math.max(0, Math.min(0.999, (deck.outerGroove - r) / (deck.outerGroove - deck.innerGroove)));
                // held at that place on the record until the player gets there
                deck.parked = false;
                deck.holdAngle = deck.startAngle + (deck.endAngle - deck.startAngle) * f;
                deck.holding = true;
                holdLimit.restart();
                deck.dragging = false;
                deck.needleDropped(f);
            }
            onCanceled: deck.dragging = false
        }
    }

    // ---------------------------------------------------------------- the front of the deck
    // the playing title, on a card in a brass holder
    Rectangle {
        id: holder
        x: 30
        y: deck.height - 72
        width: 306
        height: 50
        radius: 3
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(deck.brass, 1.2) }
            GradientStop { position: 1; color: Qt.darker(deck.brass, 1.2) }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.45)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            color: Theme.paperCard
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.35)
            Grain { anchors.fill: parent; strength: 0.9 }
            InkText {
                anchors.left: parent.left
                anchors.right: times.left
                anchors.leftMargin: 9
                anchors.rightMargin: 8
                y: 3
                text: deck.nowPlaying !== "" ? deck.nowPlaying : "Nothing on the platter."
                color: deck.nowPlaying !== "" ? Theme.graphite : Theme.faded
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            InkText {
                id: times
                anchors.right: parent.right
                anchors.rightMargin: 9
                y: 5
                text: deck.trackTimes
                color: Theme.faded
                font.pixelSize: 11
            }
            // where in the song: a ruled line, a brass slider on it; drag it
            Item {
                id: scrub
                visible: deck.nowPlaying !== ""
                x: 9
                width: parent.width - 18
                y: parent.height - 12
                height: 10
                readonly property real at: scrubArea.pressed ? scrubArea.f : Math.max(0, Math.min(1, deck.trackProgress))
                Rectangle { y: 4.5; width: parent.width; height: 1; color: Theme.faded; opacity: 0.6 }
                Rectangle { y: 4; width: parent.width * scrub.at; height: 2; color: Theme.graphite; opacity: 0.8 }
                Rectangle {
                    x: parent.width * scrub.at - 3
                    y: 0
                    width: 6; height: 10; radius: 1.5
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(deck.brass, 1.25) }
                        GradientStop { position: 1; color: Qt.darker(deck.brass, 1.25) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.5)
                }
                MouseArea {
                    id: scrubArea
                    anchors.fill: parent
                    anchors.topMargin: -6
                    anchors.bottomMargin: -4
                    cursorShape: Qt.PointingHandCursor
                    property real f: 0
                    function fAt(m) { return Math.max(0, Math.min(1, m.x / width)); }
                    onPressed: m => f = fAt(m)
                    onPositionChanged: m => { if (pressed) f = fAt(m); }
                    onReleased: deck.scrubbed(f)
                }
            }
        }
        // rivets
        Repeater {
            model: 2
            Rectangle {
                required property int index
                width: 5; height: 5; radius: 2.5
                x: index === 0 ? 1.5 : holder.width - 6.5
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.darker(deck.brass, 1.4)
            }
        }
    }

    // previous, pause / play, next: brass push buttons standing in the plinth,
    // all one size, their caps centred on the title holder
    Row {
        x: holder.x + holder.width + 10
        y: holder.y + holder.height / 2 - (30 / 2 + 4)
        spacing: 2
        Repeater {
            model: ["previous", "toggle", "next"]
            RaisedButton {
                required property string modelData
                kind: modelData
                tone: "brass"
                size: 30
                playing: deck.spinning
                onClicked: {
                    if (modelData === "previous") deck.previousAsked();
                    else if (modelData === "next") deck.nextAsked();
                    else deck.toggled();
                }
            }
        }
    }

    // the volume knob: scroll it
    Item {
        id: knob
        visible: deck.volumeShown
        // on the photograph's own knob (509, 482), else drawn
        x: deck.art ? 477 : deck.width - 96
        y: deck.art ? 450 : deck.height - 92
        width: 64; height: 64
        Canvas {
            anchors.fill: parent
            readonly property color b: deck.brass
            onBChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const c = 32;
                // the scale engraved round it
                g.strokeStyle = Qt.rgba(1, 0.94, 0.84, 0.35);
                g.lineWidth = 1;
                for (let i = 0; i <= 10; i++) {
                    const a = (135 + i * 27) * Math.PI / 180;
                    g.beginPath();
                    g.moveTo(c + Math.cos(a) * 27, c + Math.sin(a) * 27);
                    g.lineTo(c + Math.cos(a) * (i % 5 === 0 ? 32 : 30), c + Math.sin(a) * (i % 5 === 0 ? 32 : 30));
                    g.stroke();
                }
            }
        }
        Rectangle {
            id: knobCap
            visible: !deck.art
            anchors.centerIn: parent
            width: 42; height: 42; radius: 21
            rotation: -135 + 270 * Math.min(1, deck.volume / 130)
            Behavior on rotation { NumberAnimation { duration: Theme.dur(120) } }
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(deck.brass, 1.35) }
                GradientStop { position: 1; color: Qt.darker(deck.brass, 1.45) }
            }
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4; width: 3; height: 12; radius: 1.5; color: Qt.rgba(0.1, 0.07, 0.04, 0.8) }
        }
        // the photographed knob's pointer: a scratched line that turns
        Item {
            visible: deck.art
            anchors.centerIn: parent
            width: 44; height: 44
            rotation: -135 + 270 * Math.min(1, deck.volume / 130)
            Behavior on rotation { NumberAnimation { duration: Theme.dur(120) } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 4; width: 2.5; height: 12; radius: 1.2; color: Qt.rgba(0.1, 0.06, 0.03, 0.75) }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + 1
            text: "VOL. " + deck.volume
            font.family: Theme.typewriter
            font.pixelSize: 10
            font.letterSpacing: 1.5
            color: Qt.rgba(1, 0.94, 0.84, 0.55)
        }
        MouseArea {
            anchors.fill: parent
            onWheel: wheel => deck.volumeAsked(deck.volume + (wheel.angleDelta.y > 0 ? 5 : -5))
        }
    }
}
