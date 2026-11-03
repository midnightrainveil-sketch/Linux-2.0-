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
// crumble: the seal and its ribbon break together into fragments (each with
// its own piece of wax and silk), which drop away with a few crumbs.
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
    // a Voronoi split of the picture: most of the sites over the wax, some
    // along the ribbon's tails, so both break into pieces of a like size
    readonly property var pieces: {
        const rnd = Rand.make(seed + 11);
        const sites = [];
        for (let i = 0; i < 13; i++) {
            const a = rnd() * Math.PI * 2, d = Math.sqrt(rnd()) * r * 1.05;
            sites.push([c + Math.cos(a) * d, c + Math.sin(a) * d]);
        }
        for (const side of [-1, 1])
            for (let i = 0; i < 3; i++) {
                const t = (i + 0.5 + (rnd() - 0.5) * 0.4) / 3;
                sites.push([c + side * (12 + 64 * t), 168 + 60 * t]);
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
            let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, cx = 0, cy = 0;
            for (const p of poly) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); cx += p[0]; cy += p[1]; }
            cx /= poly.length; cy /= poly.length;
            // how it falls: outward from the middle, a little up first, a turn
            const away = Math.atan2(cy - c, cx - c), dist = Math.hypot(cx - c, cy - c);
            out.push({
                poly: poly, x: Math.floor(x0), y: Math.floor(y0),
                w: Math.ceil(x1) - Math.floor(x0), h: Math.ceil(y1) - Math.floor(y0),
                cx: cx, cy: cy,
                vx: Math.cos(away) * (18 + rnd() * 34) * Math.min(1, dist / 40 + 0.3),
                vy: -18 - rnd() * 26,
                spin: (rnd() - 0.5) * 140,
                delay: 0.06 * dist / r + rnd() * 0.08
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
            // its own time, a moment after the pieces nearer the middle
            readonly property real tt: Math.max(0, seal.t - p.delay)
            // (as positions: outward, up a little, then down under gravity)
            transform: [
                Rotation { origin.x: piece.p.cx - piece.p.x; origin.y: piece.p.cy - piece.p.y; angle: piece.p.spin * piece.tt },
                Translate { x: piece.p.vx * piece.tt; y: piece.p.vy * piece.tt + 420 * piece.tt * piece.tt }
            ]
            opacity: Math.max(0, 1 - Math.pow(Math.max(0, tt - 0.25) / 0.55, 2))

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
                    g.beginPath();
                    const poly = piece.p.poly;
                    g.moveTo(poly[0][0], poly[0][1]);
                    for (let i = 1; i < poly.length; i++) g.lineTo(poly[i][0], poly[i][1]);
                    g.closePath();
                    g.clip();
                    g.drawImage(seal.image, 0, 0, seal.width, seal.height);
                }
            }
        }
    }

    // crumbs of wax shaken off
    Repeater {
        model: 9
        Rectangle {
            required property int index
            readonly property var rnd: Rand.make(seal.seed * 7 + index)
            readonly property real a: rnd() * Math.PI * 2
            readonly property real d: rnd() * seal.r * 0.9
            readonly property real vx: Math.cos(a) * (30 + rnd() * 60)
            readonly property real vy: -30 - rnd() * 40
            readonly property real size: 2 + rnd() * 3.5
            readonly property real tt: Math.max(0, seal.t - 0.03 * (index % 4))
            x: seal.c + Math.cos(a) * d + vx * tt - size / 2
            y: seal.c + Math.sin(a) * d + vy * tt + 460 * tt * tt
            width: size
            height: size * (0.7 + 0.3 * (index % 2))
            radius: size * 0.35
            rotation: (rnd() - 0.5) * 600 * tt
            color: Qt.darker("#5e1c1b", 1 + 0.12 * (index % 3))
            visible: seal.broken
            opacity: Math.max(0, 1 - tt * 1.5)
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
        duration: Theme.dur(1000)
    }
}
