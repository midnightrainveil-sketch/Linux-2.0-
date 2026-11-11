import QtQuick
import qs.theme
import "Rand.js" as Rand

// A hand-drawn pencil ring in accent.ink: the way an archivist circles the
// chosen word on a typed form. Fill the parent of whatever it circles.
Canvas {
    id: root

    property color color: Theme.accent
    property int seed: 5
    property real weight: 1.3
    property real progress: 1.0      // animate 0 -> 1 to "draw" the ring

    renderStrategy: Canvas.Cooperative
    onColorChanged: requestPaint()
    onProgressChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = Rand.make(seed);
        const cx = width / 2, cy = height / 2;
        const rx = width / 2 - 2, ry = height / 2 - 2;
        const start = -2.2 + r() * 0.6;
        const sweep = Math.PI * 2 * 1.12 * progress;   // overshoots, like a real loop
        ctx.strokeStyle = color;
        ctx.lineWidth = weight;
        ctx.lineCap = "round";
        ctx.beginPath();
        const steps = 48;
        for (let i = 0; i <= steps; i++) {
            const t = i / steps;
            const a = start + sweep * t;
            const wob = 1 + (r() - 0.5) * 0.05 + t * 0.06;     // spirals out a touch
            const x = cx + rx * wob * Math.cos(a);
            const y = cy + ry * wob * Math.sin(a) - t * 1.5;
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.globalAlpha = 0.9;
        ctx.stroke();
    }
}
