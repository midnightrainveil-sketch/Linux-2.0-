import QtQuick
import qs.theme
import qs.services
import "../../components/Rand.js" as Rand

// A wax seal: a blob of madder wax pressed with the archive's matrix (a
// sprig inside a ring of lettering), two ribbon tails under it. It lands
// when the reading room locks and cracks in two when the right signature
// is given.
Item {
    id: seal

    property bool landed: false
    property bool cracked: false
    property int seed: 1907
    property string legend: Settings.archiveStamp

    readonly property real r: 54
    readonly property color wax: Theme.night > 0.5 ? "#6b2630" : "#7b2b25"

    width: 150
    height: 150

    // ---------------------------------------------------------------- drawing
    // the blob's edge: a wobbling circle with a few runs of wax
    function edge(g, R) {
        const rnd = Rand.make(seed);
        const a1 = rnd() * 6, a2 = rnd() * 6, a3 = rnd() * 6;
        const runs = [rnd() * Math.PI * 2, rnd() * Math.PI * 2, rnd() * Math.PI * 2];
        const c = width / 2;
        g.beginPath();
        for (let i = 0; i <= 120; i++) {
            const t = i / 120 * Math.PI * 2;
            let k = 1 + 0.035 * Math.sin(3 * t + a1) + 0.025 * Math.sin(7 * t + a2) + 0.012 * Math.sin(13 * t + a3);
            for (const run of runs) {
                const d = Math.atan2(Math.sin(t - run), Math.cos(t - run));
                k += 0.10 * Math.exp(-d * d * 60);
            }
            const x = c + Math.cos(t) * R * k, y = c + Math.sin(t) * R * k;
            if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
        }
        g.closePath();
    }

    // the matrix's sprig, drawn about (0, 0), 60 px tall
    function sprig(g) {
        g.beginPath();
        g.moveTo(0, 30); g.bezierCurveTo(-2, 12, 3, -6, 0, -28);
        for (let i = 0; i < 5; i++) {
            const y = 20 - i * 10, s = 1 - i * 0.12;
            // a pair of leaves
            g.moveTo(0.5, y); g.quadraticCurveTo(10 * s, y - 2, 14 * s, y - 9 * s); g.quadraticCurveTo(6 * s, y - 6 * s, 0.5, y);
            g.moveTo(-0.5, y - 4); g.quadraticCurveTo(-10 * s, y - 6, -14 * s, y - 13 * s); g.quadraticCurveTo(-6 * s, y - 10 * s, -0.5, y - 4);
        }
        // a small flower at the tip
        for (let p = 0; p < 5; p++) {
            const a = p / 5 * Math.PI * 2 - Math.PI / 2;
            g.moveTo(0, -28);
            g.arc(Math.cos(a) * 4, -28 + Math.sin(a) * 4, 2.6, 0, Math.PI * 2);
        }
    }

    function ringText(g, R) {
        const text = (" " + legend + " · ").toUpperCase();
        const c = width / 2;
        g.font = "bold 8px '" + Theme.typewriter + "'";
        g.textAlign = "center";
        g.textBaseline = "middle";
        const n = text.length;
        for (let i = 0; i < n; i++) {
            const a = -Math.PI / 2 + i / n * Math.PI * 2;
            g.save();
            g.translate(c + Math.cos(a) * R, c + Math.sin(a) * R);
            g.rotate(a + Math.PI / 2);
            g.fillText(text[i], 0, 0);
            g.restore();
        }
    }

    // raised work: shadow below-right, light above-left, then the wax
    function emboss(g, draw, fill) {
        const parts = [[1.3, 1.3, Qt.rgba(0, 0, 0, 0.45)], [-0.9, -0.9, Qt.rgba(1, 0.85, 0.8, 0.35)], [0, 0, String(Qt.lighter(wax, 1.12))]];
        for (const [dx, dy, col] of parts) {
            g.save();
            g.translate(dx, dy);
            if (fill) { g.fillStyle = col; draw(); g.fill(); }
            else { g.strokeStyle = col; g.fillStyle = col; draw(); }
            g.restore();
        }
    }

    function paintSeal(g, clip) {
        g.reset();
        const c = width / 2, R = r;
        if (clip) { g.beginPath(); clip(g); g.clip(); }
        // the wax, lit from the top left
        edge(g, R);
        const body = g.createRadialGradient(c - R * 0.35, c - R * 0.4, R * 0.1, c, c, R * 1.15);
        body.addColorStop(0, String(Qt.lighter(wax, 1.35)));
        body.addColorStop(0.55, String(wax));
        body.addColorStop(1, String(Qt.darker(wax, 1.7)));
        g.fillStyle = body;
        g.fill();
        g.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
        g.lineWidth = 1;
        g.stroke();
        // the matrix's impression: a sunken disc
        const Ri = R * 0.76;
        g.beginPath(); g.arc(c, c, Ri, 0, Math.PI * 2);
        const sunk = g.createLinearGradient(c - Ri, c - Ri, c + Ri, c + Ri);
        sunk.addColorStop(0, String(Qt.darker(wax, 1.25)));
        sunk.addColorStop(1, String(Qt.lighter(wax, 1.08)));
        g.fillStyle = sunk;
        g.fill();
        g.lineWidth = 2;
        g.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
        g.beginPath(); g.arc(c, c, Ri, Math.PI * 0.75, Math.PI * 1.75); g.stroke();
        g.strokeStyle = Qt.rgba(1, 0.85, 0.8, 0.28);
        g.beginPath(); g.arc(c, c, Ri, -Math.PI * 0.25, Math.PI * 0.75); g.stroke();
        // the lettering and an inner ring, raised
        emboss(g, () => ringText(g, Ri - 8), false);
        emboss(g, () => { g.lineWidth = 1; g.beginPath(); g.arc(c, c, Ri - 15, 0, Math.PI * 2); g.stroke(); }, false);
        // the sprig, raised
        emboss(g, () => { g.save(); g.translate(c, c + 1); g.scale(0.82, 0.82); g.beginPath(); sprig(g); g.restore(); }, true);
        // the gloss
        g.fillStyle = Qt.rgba(1, 1, 1, 0.16);
        g.beginPath(); g.ellipse(c - R * 0.72, c - R * 0.86, R * 0.55, R * 0.28); g.fill();
    }

    // the crack, from the top edge to the bottom, wandering
    readonly property var crackPts: {
        const rnd = Rand.make(seed + 5);
        const pts = [];
        const c = width / 2;
        for (let i = 0; i <= 10; i++) pts.push([c + (rnd() - 0.5) * 16 + (i === 5 ? 6 : 0), i / 10 * height]);
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

    // ---------------------------------------------------------------- the ribbon tails
    Repeater {
        model: [-1, 1]
        Canvas {
            required property int modelData
            readonly property int side: modelData
            x: seal.width / 2 - (side < 0 ? width - 10 : 10)
            y: seal.height / 2 + 4
            width: 60; height: 76
            opacity: seal.landed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(300) } }
            readonly property color c: Theme.accent
            onCChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                if (side < 0) { g.translate(width, 0); g.scale(-1, 1); }
                // a tail running down and out, its end cut in a V
                g.fillStyle = String(c);
                g.globalAlpha = 0.85;
                g.beginPath();
                g.moveTo(0, 0); g.lineTo(18, 0);
                g.lineTo(46, 66); g.lineTo(37, 60); g.lineTo(30, 72);
                g.closePath();
                g.fill();
                g.globalAlpha = 0.25;
                g.strokeStyle = "white";
                g.lineWidth = 1;
                g.beginPath(); g.moveTo(6, 0); g.lineTo(36, 66); g.stroke();
            }
        }
    }

    // ---------------------------------------------------------------- the seal: whole, then in halves
    Item {
        id: whole
        anchors.fill: parent
        visible: !seal.cracked
        opacity: 0
        scale: 1.5
        Canvas {
            anchors.fill: parent
            readonly property color w: seal.wax
            onWChanged: requestPaint()
            onPaint: seal.paintSeal(getContext("2d"), null)
        }
    }
    Repeater {
        model: [-1, 1]
        Canvas {
            id: half
            required property int modelData
            anchors.fill: parent
            // (always drawn, only hidden: a canvas painted while hidden may never paint)
            readonly property color w: seal.wax
            onWChanged: requestPaint()
            onPaint: seal.paintSeal(getContext("2d"), modelData < 0 ? seal.leftOf : seal.rightOf)
            transformOrigin: Item.Bottom
            property real fall: 0
            x: modelData * 26 * fall
            y: 50 * fall * fall
            rotation: modelData * 28 * fall
            opacity: seal.cracked ? 1 - fall * fall : 0
            Connections {
                target: seal
                function onCrackedChanged() {
                    if (seal.cracked) breaking.restart();
                    else { breaking.stop(); half.fall = 0; }
                }
            }
            NumberAnimation {
                id: breaking
                target: half
                property: "fall"
                from: 0; to: 1
                duration: Theme.dur(650)
                easing.type: Easing.InCubic
            }
        }
    }

    // ---------------------------------------------------------------- landing
    Component.onCompleted: if (landed) pressing.restart()
    onLandedChanged: {
        if (landed) { pressing.restart(); }
        else { pressing.stop(); whole.opacity = 0; whole.scale = 1.5; }
    }
    SequentialAnimation {
        id: pressing
        PauseAnimation { duration: Theme.dur(250) }
        ParallelAnimation {
            NumberAnimation { target: whole; property: "opacity"; from: 0; to: 1; duration: Theme.dur(160) }
            NumberAnimation { target: whole; property: "scale"; from: 1.5; to: 0.95; duration: Theme.dur(200); easing.type: Easing.InCubic }
        }
        // the wax gives under the matrix, and settles
        NumberAnimation { target: whole; property: "scale"; to: 1.0; duration: Theme.dur(220); easing.type: Easing.OutBack }
    }
}
