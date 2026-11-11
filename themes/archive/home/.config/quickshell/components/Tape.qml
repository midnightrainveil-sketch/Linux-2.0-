import QtQuick
import qs.theme
import "Rand.js" as Rand

// Tape strip (section 7): translucent #E8E4DC at 55 % with torn ends.
// Only on the wallpaper and on a pinned notification; one per card.
Canvas {
    id: root

    property int seed: 21
    property color color: Theme.tape

    implicitWidth: 64
    implicitHeight: 18
    renderStrategy: Canvas.Cooperative
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = Rand.make(seed);
        const w = width, h = height, teeth = 6;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(3 + r() * 3, 0);
        ctx.lineTo(w - 3 - r() * 3, 0.5);
        for (let i = 1; i <= teeth; i++)               // torn right end
            ctx.lineTo(w - (i % 2 ? r() * 4 : 3 + r() * 3), h * i / teeth);
        ctx.lineTo(3 + r() * 3, h - 0.5);
        for (let i = teeth - 1; i >= 0; i--)           // torn left end
            ctx.lineTo((i % 2 ? r() * 4 : 3 + r() * 3), h * i / teeth);
        ctx.closePath();
        ctx.fill();
        // faint fibre streaks
        ctx.globalAlpha = 0.18;
        ctx.strokeStyle = Theme.paperBase;
        ctx.lineWidth = 0.6;
        for (let i = 0; i < 5; i++) {
            const y = 2 + r() * (h - 4);
            ctx.beginPath(); ctx.moveTo(6, y); ctx.lineTo(w - 6, y + (r() - 0.5) * 2); ctx.stroke();
        }
    }
}
