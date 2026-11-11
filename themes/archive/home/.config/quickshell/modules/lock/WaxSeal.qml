import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import "../../components/Rand.js" as Rand

// A wax seal with its ribbon: red wax pressed with a flowering sprig in a
// beaded ring, two tails of blue silk running out from under it, one picture
// (assets/seal/sealed.png, tools/make_sealed.py), a little darker at night.
//
// It is simply there while the room is locked. The right signature makes it
// crumble like a biscuit: seal and ribbon give way together into rough,
// thick lumps (each with its own wax and silk) that tumble down, shedding
// crumbs and dust as they go.
Item {
    id: seal

    property bool landed: false
    property bool cracked: false
    property int seed: 1907
    signal stamped()            // (kept for the room; the seal no longer presses)

    readonly property url image: Qt.resolvedUrl("../../assets/seal/sealed.png")
    readonly property real c: 120               // the wax's centre, in the picture
    readonly property real r: 58                // and its radius

    width: 240
    height: 240

    // by night, under the blue sheet, a little darker and duller
    layer.enabled: Theme.night > 0.01
    layer.effect: MultiEffect {
        brightness: -0.18 * Theme.night
        saturation: -0.25 * Theme.night
    }

    // ---------------------------------------------------------------- the fragments
    // a Voronoi split of the picture, its cuts made rough and crumbly (each
    // shared edge wanders the same way for both of its pieces): many pieces
    // over the wax, a few along the ribbon's tails
    function hash(a: real, b: real): real {
        const v = Math.sin(a * 12.9898 + b * 78.233 + seal.seed * 0.137) * 43758.5453;
        return v - Math.floor(v);
    }
    // a rough line from p to q, the same points whichever way it is walked
    function roughEdge(p, q) {
        const flip = p[0] > q[0] || (p[0] === q[0] && p[1] > q[1]);
        const a = flip ? q : p, b = flip ? p : q;
        const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
        const onBox = (a[0] <= 0.01 && b[0] <= 0.01) || (a[1] <= 0.01 && b[1] <= 0.01)
            || (a[0] >= width - 0.01 && b[0] >= width - 0.01) || (a[1] >= height - 0.01 && b[1] >= height - 0.01);
        const n = onBox ? 1 : Math.max(2, Math.ceil(L / 3.2));
        const nx = -(b[1] - a[1]) / (L || 1), ny = (b[0] - a[0]) / (L || 1);
        const pts = [];
        for (let i = 1; i < n; i++) {
            const t = i / n;
            const j = (hash(a[0] * 7.1 + b[0] * 3.3 + i, a[1] * 5.7 + b[1] * 9.1 + i * 1.7) - 0.5) * 3.4
                    + (hash(i * 3.1 + a[0], b[1] + i) - 0.5) * 1.4;
            pts.push([a[0] + (b[0] - a[0]) * t + nx * j, a[1] + (b[1] - a[1]) * t + ny * j]);
        }
        return flip ? pts.reverse() : pts;
    }
    readonly property var pieces: {
        const rnd = Rand.make(seed + 11);
        const sites = [];
        for (let i = 0; i < 22; i++) {
            const a = rnd() * Math.PI * 2, d = Math.pow(rnd(), 0.6) * r * 1.05;
            sites.push([c + Math.cos(a) * d, c + Math.sin(a) * d]);
        }
        for (const side of [-1, 1])
            for (let i = 0; i < 4; i++) {
                const t = (i + 0.5 + (rnd() - 0.5) * 0.4) / 4;
                sites.push([c + side * (14 + 70 * t), 168 + 62 * t]);
            }
        const out = [];
        for (let i = 0; i < sites.length; i++) {
            let poly = [[0, 0], [width, 0], [width, height], [0, height]];
            const [px, py] = sites[i];
            for (let j = 0; j < sites.length && poly.length; j++) {
                if (j === i) continue;
                // keep the side of the bisector nearer site i
                const [qx, qy] = sites[j];
                const nx = qx - px, ny = qy - py, m = (nx * (px + qx) + ny * (py + qy)) / 2;
                const inside = p => p[0] * nx + p[1] * ny <= m;
                const next = [];
                for (let k = 0; k < poly.length; k++) {
                    const a = poly[k], b = poly[(k + 1) % poly.length];
                    const ia = inside(a), ib = inside(b);
                    if (ia) next.push(a);
                    if (ia !== ib) {
                        const da = a[0] * nx + a[1] * ny - m, db = b[0] * nx + b[1] * ny - m;
                        const f = da / (da - db);
                        next.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]);
                    }
                }
                poly = next;
            }
            if (poly.length < 3) continue;
            // (corners rounded to a grid, so neighbours share them exactly)
            poly = poly.map(p => [Math.round(p[0] * 100) / 100, Math.round(p[1] * 100) / 100]);
            const rough = [];
            for (let k = 0; k < poly.length; k++) {
                rough.push(poly[k]);
                for (const q of roughEdge(poly[k], poly[(k + 1) % poly.length])) rough.push(q);
            }
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, cx = 0, cy = 0;
            for (const p of rough) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
            for (const p of poly) { cx += p[0]; cy += p[1]; }
            cx /= poly.length; cy /= poly.length;
            const dist = Math.hypot(cx - c, cy - c);
            const wax = dist < r * 1.02;
            const pad = 4;
            out.push({
                poly: rough, x: Math.floor(x0) - pad, y: Math.floor(y0) - pad,
                w: Math.ceil(x1) - Math.floor(x0) + 2 * pad, h: Math.ceil(y1) - Math.floor(y0) + 2 * pad,
                cx: cx, cy: cy, wax: wax,
                // a cookie gives way and drops: mostly down, barely outward,
                // tumbling over as it goes; the middle first, the rim after
                vx: (cx - c) * (0.15 + rnd() * 0.25) + (rnd() - 0.5) * 14,
                vy: 6 + rnd() * 18,
                g: 380 + rnd() * 160,
                spin: (rnd() - 0.5) * 120,
                tumble: (90 + rnd() * 160) * (rnd() < 0.5 ? -1 : 1),
                ax: rnd() - 0.5, ay: rnd() - 0.5,
                delay: 0.05 * (1 - Math.min(1, dist / r)) + 0.09 * Math.min(1, dist / r) * rnd() + (wax ? 0 : 0.06)
            });
        }
        return out;
    }

    // ---------------------------------------------------------------- whole
    Image {
        id: whole
        anchors.fill: parent
        source: seal.image
        sourceSize: Qt.size(seal.width * 2, seal.height * 2)
        smooth: true
        mipmap: true
        visible: !seal.broken
        opacity: seal.landed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutQuad } }
    }

    // ---------------------------------------------------------------- crumbling
    property bool broken: false
    property real t: 0              // the fall, in seconds of its own

    Repeater {
        model: seal.pieces
        Item {
            id: piece
            required property var modelData
            readonly property var p: modelData
            x: p.x
            y: p.y
            width: p.w
            height: p.h
            visible: seal.broken
            // its own time: the middle gives first, then the rest
            readonly property real tt: Math.max(0, seal.t - p.delay)
            transform: [
                // tumbling over as it falls (seen foreshortened, its side
                // showing), turning a little, dropping under its weight
                Rotation {
                    origin.x: piece.p.cx - piece.p.x; origin.y: piece.p.cy - piece.p.y
                    axis { x: piece.p.ax; y: piece.p.ay; z: 0 }
                    angle: piece.p.tumble * piece.tt * piece.tt * 1.6
                },
                Rotation { origin.x: piece.p.cx - piece.p.x; origin.y: piece.p.cy - piece.p.y; angle: piece.p.spin * piece.tt },
                Translate { x: piece.p.vx * piece.tt; y: piece.p.vy * piece.tt + piece.p.g * piece.tt * piece.tt }
            ]
            opacity: Math.max(0, 1 - Math.pow(Math.max(0, tt - 0.35) / 0.5, 2))

            Canvas {
                // drawn at twice its size for a crisp edge, shown at its own
                width: piece.width * 2
                height: piece.height * 2
                scale: 0.5
                transformOrigin: Item.TopLeft
                Component.onCompleted: loadImage(seal.image)
                onImageLoaded: requestPaint()
                onPaint: {
                    if (!isImageLoaded(seal.image)) return;
                    const g = getContext("2d");
                    g.reset();
                    g.scale(2, 2);
                    g.translate(-piece.p.x, -piece.p.y);
                    const poly = piece.p.poly;
                    const path = () => {
                        g.beginPath();
                        g.moveTo(poly[0][0], poly[0][1]);
                        for (let i = 1; i < poly.length; i++) g.lineTo(poly[i][0], poly[i][1]);
                        g.closePath();
                    };
                    // its thickness: the broken side of the wax, darker,
                    // below the face (the silk is thin: hardly any)
                    const dy = piece.p.wax ? 2.4 : 0.7;
                    g.save();
                    g.translate(0.5, dy);
                    path(); g.clip();
                    g.drawImage(seal.image, 0, 0, seal.width, seal.height);
                    g.globalCompositeOperation = "source-atop";
                    g.fillStyle = Qt.rgba(0.14, 0.03, 0.03, 0.62);
                    g.fillRect(-10, -10, seal.width + 20, seal.height + 20);
                    g.restore();
                    // the face
                    g.save();
                    path(); g.clip();
                    g.drawImage(seal.image, 0, 0, seal.width, seal.height);
                    // the fresh break along its rim: matte, a little paler
                    g.globalCompositeOperation = "source-atop";
                    path();
                    g.lineWidth = 2.2;
                    g.strokeStyle = Qt.rgba(0.62, 0.32, 0.29, 0.45);
                    g.stroke();
                    g.restore();
                }
            }
        }
    }

    // crumbs and dust, shaken off all the way down: the cookie keeps crumbling
    Repeater {
        model: 56
        Rectangle {
            required property int index
            readonly property var rnd: Rand.make(seal.seed * 7 + index * 13)
            readonly property real a: rnd() * Math.PI * 2
            readonly property real d: Math.pow(rnd(), 0.5) * seal.r * 0.98
            readonly property real born: rnd() * 0.45            // when it comes loose
            readonly property real vx: Math.cos(a) * (6 + rnd() * 26)
            readonly property real vy: -6 + rnd() * 20
            readonly property real grav: 420 + rnd() * 220
            readonly property bool dust: index % 3 === 0
            readonly property real size: dust ? 0.8 + rnd() * 0.9 : 1.4 + rnd() * 2.8
            readonly property real tt: Math.max(0, seal.t - born)
            x: seal.c + Math.cos(a) * d + vx * tt - size / 2
            y: seal.c + Math.sin(a) * d + vy * tt + grav * tt * tt
            width: size
            height: size * (0.6 + 0.4 * rnd())
            radius: size * (0.2 + 0.25 * rnd())
            rotation: rnd() * 180 + (rnd() - 0.5) * 500 * tt
            color: dust ? Qt.rgba(0.55, 0.28, 0.25, 1) : Qt.darker("#6a2220", 1 + 0.25 * rnd())
            visible: seal.broken && seal.t > born
            opacity: Math.max(0, (dust ? 0.7 : 1) - tt * 1.3)
        }
    }

    onCrackedChanged: {
        if (cracked) { broken = true; t = 0; crumbling.restart(); }
        else { crumbling.stop(); broken = false; t = 0; }
    }
    onLandedChanged: if (!landed) { crumbling.stop(); broken = false; t = 0; }
    NumberAnimation {
        id: crumbling
        target: seal
        property: "t"
        from: 0
        to: 1.0
        duration: Theme.dur(1150)
    }
}
