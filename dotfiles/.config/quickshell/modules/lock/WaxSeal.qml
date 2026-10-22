import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import "../../components/Rand.js" as Rand

// A wax seal: red wax pressed with a flowering sprig in a beaded ring (the
// picture assets/seal/seal.png, from tools/import_seal.py), a silk ribbon
// under it, a little darker at night.
//
// As the room locks a drop of molten wax lands and spreads, the matrix's
// shadow closes over it, it presses (the wax squeezes out, the card takes
// the knock: stamped()) and lifts, and the fresh gloss dulls as it sets.
// The right signature cracks it: a hairline runs across, the halves part
// and fall with a few crumbs, and the ribbon slips away.
Item {
    id: seal

    property bool landed: false
    property bool cracked: false
    property int seed: 1907
    signal stamped()

    readonly property real r: 58                 // the blob's radius
    readonly property real ri: r * 0.74          // the matrix's impression
    readonly property color wax: "#8a0f0e"     // the picture's red, for the molten drop and the crumbs
    readonly property url image: Qt.resolvedUrl("../../assets/seal/seal.png")
    readonly property real k: 2                  // drawn at twice the size, for a crisp edge (Sharp)

    // a canvas drawn at twice its size and shown at its own: a crisp edge
    // on any screen (its drawing is in the seal's units, after g.scale(2, 2))
    component Sharp: Canvas {
        width: parent ? parent.width * 2 : 0
        height: parent ? parent.height * 2 : 0
        scale: 0.5
        transformOrigin: Item.TopLeft
    }

    width: 200
    height: 200

    // by night, under the blue sheet, the wax a little darker and duller
    layer.enabled: Theme.night > 0.01
    layer.effect: MultiEffect {
        brightness: -0.18 * Theme.night
        saturation: -0.25 * Theme.night
    }

    // ---------------------------------------------------------------- drawing

    // the blob's edge: a wobbling circle with a few runs of wax pushed out
    function edge(g, R, grow) {
        const rnd = Rand.make(seed);
        const a1 = rnd() * 6, a2 = rnd() * 6, a3 = rnd() * 6;
        const runs = [rnd() * Math.PI * 2, rnd() * Math.PI * 2, rnd() * Math.PI * 2, rnd() * Math.PI * 2];
        const c = width / 2;
        g.beginPath();
        for (let i = 0; i <= 160; i++) {
            const t = i / 160 * Math.PI * 2;
            let q = 1 + 0.04 * Math.sin(3 * t + a1) + 0.03 * Math.sin(5 * t + a2) + 0.015 * Math.sin(11 * t + a3);
            for (let j = 0; j < runs.length; j++) {
                const d = Math.atan2(Math.sin(t - runs[j]), Math.cos(t - runs[j]));
                q += (j % 2 ? 0.07 : 0.11) * grow * Math.exp(-d * d * 40);
            }
            const x = c + Math.cos(t) * R * q, y = c + Math.sin(t) * R * q;
            if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
        }
        g.closePath();
    }

    // molten: the blob alone, glossy, before the matrix (grow: how far it has spread)
    function paintMolten(g) {
        g.reset();
        g.scale(k, k);
        const c = width / 2, R = r * 1.0;      // as wide as the pressed seal: the press only squeezes it
        g.save();
        g.shadowColor = Qt.rgba(0, 0, 0, 0.35); g.shadowBlur = 8; g.shadowOffsetY = 3;
        edge(g, R, 0.4);
        const body = g.createRadialGradient(c - R * 0.3, c - R * 0.35, R * 0.05, c, c, R * 1.1);
        body.addColorStop(0, String(Qt.lighter(wax, 1.55)));
        body.addColorStop(0.45, String(Qt.lighter(wax, 1.1)));
        body.addColorStop(1, String(Qt.darker(wax, 1.5)));
        g.fillStyle = body;
        g.fill();
        g.restore();
        // a liquid shine
        const sh = g.createRadialGradient(c - R * 0.35, c - R * 0.42, 0, c - R * 0.35, c - R * 0.42, R * 0.5);
        sh.addColorStop(0, Qt.rgba(1, 0.95, 0.9, 0.55));
        sh.addColorStop(1, Qt.rgba(1, 0.95, 0.9, 0));
        g.fillStyle = sh;
        g.beginPath(); g.arc(c - R * 0.35, c - R * 0.42, R * 0.5, 0, Math.PI * 2); g.fill();
    }

    // the seal: the picture (assets/seal/seal.png, tools/import_seal.py),
    // within `clip` if given (a half, when it breaks)
    function paintSeal(g, clip) {
        g.reset();
        g.scale(k, k);
        if (clip) { g.beginPath(); clip(g); g.clip(); }
        const S = r * 2.6;                      // the picture's square: the wax fills 86 % of it
        g.drawImage(image, (width - S) / 2, (height - S) / 2, S, S);
    }

    // the crack, from the top edge to the bottom, wandering
    readonly property var crackPts: {
        const rnd = Rand.make(seed + 5);
        const pts = [];
        const c = width / 2;
        for (let i = 0; i <= 14; i++) pts.push([c + (rnd() - 0.5) * 18 + (i === 7 ? 7 : 0), i / 14 * height]);
        return pts;
    }
    function leftOf(g) {
        g.moveTo(0, 0);
        for (const [x, y] of crackPts) g.lineTo(x, y);
        g.lineTo(0, height);
        g.closePath();
    }
    function rightOf(g) {
        g.moveTo(width, 0);
        for (const [x, y] of crackPts) g.lineTo(x, y);
        g.lineTo(width, height);
        g.closePath();
    }

    // ---------------------------------------------------------------- the ribbon
    // two tails of silk from under the seal, down and out, cut in a V
    Item {
        id: ribbon
        anchors.fill: parent
        property real slip: 0                    // 0 lying, 1 gone (unlocked)
        opacity: (seal.landed ? 1 : 0) * (1 - slip)
        Behavior on opacity { enabled: ribbon.slip === 0; NumberAnimation { duration: Theme.dur(300) } }
        transform: Translate { y: 26 * ribbon.slip * ribbon.slip }

        Repeater {
            model: [-1, 1]
            Canvas {
                required property int modelData
                readonly property int side: modelData
                x: seal.width / 2 - (side < 0 ? width - 8 : 8)
                y: seal.height / 2 + 6
                width: 74; height: 96
                rotation: side * 3 * ribbon.slip
                readonly property color c: Theme.accent
                onCChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    if (side < 0) { g.translate(width, 0); g.scale(-1, 1); }
                    // the tail's two edges, a gentle curve, a fold half way
                    const band = (t) => [4 + 30 * t + 6 * Math.sin(t * 3), 2 + 84 * t];
                    const w = 15;
                    const L = [], Rr = [];
                    for (let i = 0; i <= 20; i++) {
                        const t = i / 20, [x, y] = band(t);
                        const ww = w * (t > 0.48 && t < 0.56 ? 0.72 : 1);     // the fold pinches it
                        L.push([x, y]); Rr.push([x + ww, y - ww * 0.35]);
                    }
                    const end = band(1);
                    g.beginPath();
                    g.moveTo(L[0][0], L[0][1]);
                    for (const p of L) g.lineTo(p[0], p[1]);
                    g.lineTo(end[0] + w * 0.55, end[1] - 9);              // the V cut
                    g.lineTo(Rr[20][0], Rr[20][1]);
                    for (let i = 20; i >= 0; i--) g.lineTo(Rr[i][0], Rr[i][1]);
                    g.closePath();
                    // silk: darker at the edges, a sheen down the middle
                    const gr = g.createLinearGradient(0, 0, 30, -8);
                    gr.addColorStop(0, String(Qt.darker(c, 1.35)));
                    gr.addColorStop(0.5, String(Qt.lighter(c, 1.25)));
                    gr.addColorStop(1, String(Qt.darker(c, 1.25)));
                    g.save();
                    g.shadowColor = Qt.rgba(0, 0, 0, 0.3); g.shadowBlur = 4; g.shadowOffsetY = 2;
                    g.fillStyle = String(c);
                    g.fill();
                    g.restore();
                    g.save();
                    g.clip();
                    g.globalAlpha = 0.55;
                    g.fillStyle = gr;
                    g.fillRect(0, 0, width, height);
                    // the fold: the far side turned towards us, in shadow
                    g.globalAlpha = 0.35;
                    g.fillStyle = "black";
                    const f0 = band(0.48), f1 = band(0.56);
                    g.beginPath(); g.moveTo(f0[0], f0[1]); g.lineTo(f0[0] + w, f0[1] - w * 0.35); g.lineTo(f1[0] + w * 0.72, f1[1] - w * 0.25); g.lineTo(f1[0], f1[1]); g.closePath(); g.fill();
                    // fine lengthways sheen lines
                    g.globalAlpha = 0.18;
                    g.strokeStyle = "white";
                    g.lineWidth = 0.6;
                    for (const off of [4, 8, 11]) {
                        g.beginPath();
                        for (let i = 0; i <= 20; i++) { const [x, y] = band(i / 20); if (i === 0) g.moveTo(x + off, y - off * 0.35); else g.lineTo(x + off, y - off * 0.35); }
                        g.stroke();
                    }
                    g.restore();
                }
            }
        }
    }

    // ---------------------------------------------------------------- the pouring and the pressing
    // the drop of molten wax
    Item {
        id: molten
        anchors.fill: parent
        opacity: 0
        scale: 0.3
        Sharp {
            readonly property color w: seal.wax
            onWChanged: requestPaint()
            onPaint: seal.paintMolten(getContext("2d"))
        }
    }
    // the matrix's shadow, closing over it as it comes down
    Canvas {
        id: matrixShadow
        anchors.centerIn: parent
        width: seal.ri * 2.8
        height: width
        opacity: 0
        scale: 1.5
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const c = width / 2;
            const sh = g.createRadialGradient(c, c, 0, c, c, c);
            sh.addColorStop(0, Qt.rgba(0.05, 0, 0, 1));
            sh.addColorStop(0.55, Qt.rgba(0.05, 0, 0, 0.8));
            sh.addColorStop(1, Qt.rgba(0.05, 0, 0, 0));
            g.fillStyle = sh;
            g.fillRect(0, 0, width, height);
        }
    }

    // the seal: whole, then in halves
    Item {
        id: whole
        anchors.fill: parent
        visible: !seal.parted         // (the hairline runs across it first)
        opacity: 0
        Sharp {
            Component.onCompleted: loadImage(seal.image)
            onImageLoaded: requestPaint()
            onPaint: if (isImageLoaded(seal.image)) seal.paintSeal(getContext("2d"), null)
        }
        // the fresh wax's gloss, dulling as it sets
        Rectangle {
            id: fresh
            anchors.centerIn: parent
            width: seal.r * 1.9
            height: width
            radius: width / 2
            opacity: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.92, 0.88, 0.55) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 0.92, 0.88, 0.0) }
            }
            rotation: -35
        }
        // the hairline crack, running across before it breaks
        Sharp {
            id: hairline
            property real run: 0
            onRunChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.scale(seal.k, seal.k);
                if (run <= 0) return;
                const pts = seal.crackPts, n = pts.length - 1, upto = run * n;
                g.lineCap = "round"; g.lineJoin = "round";
                for (const [col, w, dx] of [[Qt.rgba(1, 0.8, 0.75, 0.35), 1.6, 0.8], [Qt.rgba(0.05, 0, 0, 0.85), 1.3, 0]]) {
                    g.strokeStyle = col; g.lineWidth = w;
                    g.beginPath();
                    g.moveTo(pts[0][0] + dx, pts[0][1]);
                    for (let i = 1; i <= Math.ceil(upto); i++) {
                        const f = Math.min(1, upto - (i - 1));
                        g.lineTo(pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * f + dx, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * f);
                    }
                    g.stroke();
                }
            }
        }
    }
    Repeater {
        id: halves
        model: [-1, 1]
        Item {
            id: half
            required property int modelData
            width: seal.width
            height: seal.height
            Sharp {
                // (always drawn, only hidden: a canvas painted while hidden may never paint)
                Component.onCompleted: loadImage(seal.image)
                onImageLoaded: requestPaint()
                onPaint: if (isImageLoaded(seal.image)) seal.paintSeal(getContext("2d"), half.modelData < 0 ? seal.leftOf : seal.rightOf)
            }
            transformOrigin: Item.Bottom
            // the right half a moment behind the left
            readonly property real fall: modelData < 0 ? seal.fall : Math.max(0, seal.fall * 1.08 - 0.08)
            x: modelData * (6 + 34 * fall)
            y: 70 * fall * fall
            rotation: modelData * (4 + 32 * fall)
            opacity: seal.cracked && seal.parted ? 1 - fall * fall : 0
        }
    }
    // crumbs of wax thrown off as it breaks
    Repeater {
        id: crumbs
        model: 7
        Rectangle {
            required property int index
            readonly property var rnd: Rand.make(seal.seed * 7 + index)
            readonly property real vx: (rnd() - 0.5) * 120
            readonly property real vy: -20 - rnd() * 50
            readonly property real spin: (rnd() - 0.5) * 540
            readonly property real size: 2.5 + rnd() * 3.5
            readonly property real t: seal.scatter * (0.86 + 0.07 * (index % 3))
            x: seal.width / 2 + vx * t - size / 2
            y: seal.height / 2 + (index - 3) * 9 + vy * t + 260 * t * t
            width: size
            height: size * (0.7 + 0.3 * (index % 2))
            radius: size * 0.35
            rotation: spin * t
            color: Qt.darker(seal.wax, 1 + 0.1 * (index % 3))
            opacity: seal.parted ? Math.max(0, 1 - t * 1.4) : 0
        }
    }
    property bool parted: false
    property real fall: 0           // the halves falling, 0 to 1
    property real scatter: 0        // the crumbs flying, 0 to 1

    // ---------------------------------------------------------------- the lock: pour, press, set
    Component.onCompleted: if (landed) pressing.restart()
    onLandedChanged: {
        if (landed) pressing.restart();
        else { pressing.stop(); reset(); }
    }
    function reset(): void {
        molten.opacity = 0; molten.scale = 0.3;
        matrixShadow.opacity = 0; matrixShadow.scale = 1.5;
        whole.opacity = 0; whole.scale = 1;
        fresh.opacity = 0;
        hairline.run = 0;
        ribbon.slip = 0;
        parted = false;
        fall = 0;
        scatter = 0;
    }
    SequentialAnimation {
        id: pressing
        ScriptAction { script: seal.reset() }
        PauseAnimation { duration: Theme.dur(220) }
        // the drop lands and spreads
        ParallelAnimation {
            NumberAnimation { target: molten; property: "opacity"; from: 0; to: 1; duration: Theme.dur(90) }
            NumberAnimation { target: molten; property: "scale"; from: 0.3; to: 1.0; duration: Theme.dur(420); easing.type: Easing.OutCubic }
        }
        // the matrix comes down: its shadow gathers and tightens
        ParallelAnimation {
            NumberAnimation { target: matrixShadow; property: "opacity"; to: 0.38; duration: Theme.dur(260); easing.type: Easing.InQuad }
            NumberAnimation { target: matrixShadow; property: "scale"; to: 0.82; duration: Theme.dur(260); easing.type: Easing.InQuad }
        }
        // the press: the wax squeezes out under it, the card takes the knock
        ScriptAction { script: { matrixShadow.opacity = 0; molten.opacity = 0; whole.opacity = 1; whole.scale = 0.92; fresh.opacity = 1; seal.stamped(); } }
        NumberAnimation { target: whole; property: "scale"; to: 1.0; duration: Theme.dur(380); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        // and as it cools, the gloss dulls
        NumberAnimation { target: fresh; property: "opacity"; to: 0; duration: Theme.dur(900); easing.type: Easing.OutQuad }
    }

    // ---------------------------------------------------------------- the unlock: crack, part, fall
    onCrackedChanged: {
        if (cracked) { pressing.stop(); fresh.opacity = 0; whole.opacity = 1; whole.scale = 1; molten.opacity = 0; matrixShadow.opacity = 0; breaking.restart(); }
        else { breaking.stop(); reset(); if (landed) { whole.opacity = 1; } }
    }
    SequentialAnimation {
        id: breaking
        // a hairline runs across it
        NumberAnimation { target: hairline; property: "run"; from: 0; to: 1; duration: Theme.dur(170); easing.type: Easing.InQuad }
        PauseAnimation { duration: Theme.dur(70) }
        // it gives: the halves part and fall, crumbs fly, the ribbon slips away
        ScriptAction { script: seal.parted = true }
        ParallelAnimation {
            NumberAnimation { target: seal; property: "fall"; from: 0; to: 1; duration: Theme.dur(740); easing.type: Easing.InQuad }
            NumberAnimation { target: seal; property: "scatter"; from: 0; to: 1; duration: Theme.dur(700) }
            NumberAnimation { target: ribbon; property: "slip"; from: 0; to: 1; duration: Theme.dur(650); easing.type: Easing.InQuad }
        }
    }
}
