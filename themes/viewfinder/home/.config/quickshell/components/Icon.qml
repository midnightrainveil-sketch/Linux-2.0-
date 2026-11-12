import QtQuick
import qs.theme

// Line icons, drawn here (no icon font, no picture files): thin white
// strokes on a 24-unit grid.
Canvas {
    id: root
    property string name: ""
    property real size: 22
    property color color: Theme.ink
    property real weight: 1.6

    width: size
    height: size
    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onSizeChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const k = size / 24;
        c.scale(k, k);
        c.strokeStyle = color;
        c.fillStyle = color;
        c.lineWidth = weight / k;
        c.lineJoin = "round";
        c.lineCap = "round";
        const line = (...p) => { c.beginPath(); c.moveTo(p[0], p[1]); for (let i = 2; i < p.length; i += 2) c.lineTo(p[i], p[i + 1]); c.stroke(); };
        const shape = (...p) => { c.beginPath(); c.moveTo(p[0], p[1]); for (let i = 2; i < p.length; i += 2) c.lineTo(p[i], p[i + 1]); c.closePath(); };
        const box = (x, y, w, h, r) => { c.beginPath(); c.roundedRect(x, y, w, h, r, r); c.stroke(); };
        const ring = (x, y, r) => { c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.stroke(); };
        const dot = (x, y, r) => { c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); };
        const cloud = () => {
            c.beginPath();
            c.moveTo(7, 15);
            c.bezierCurveTo(3.5, 15, 3, 10.5, 6.6, 10);
            c.bezierCurveTo(7, 6, 12.5, 5, 14.2, 8.4);
            c.bezierCurveTo(18, 7.6, 20.4, 11, 18.8, 13.4);
            c.bezierCurveTo(18.2, 14.6, 17.2, 15, 16, 15);
            c.closePath();
            c.stroke();
        };

        switch (name) {
        case "camera":
            box(2.5, 6.5, 19, 13, 1.5); line(8, 6.5, 9.5, 4, 14.5, 4, 16, 6.5); ring(12, 13, 3.6); break;
        case "rain":
            cloud(); line(8, 18, 7.2, 20.5); line(12, 18, 11.2, 20.5); line(16, 18, 15.2, 20.5); break;
        case "cloud":
            c.translate(0, 2); cloud(); break;
        case "sun":
            ring(12, 12, 4);
            for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; line(12 + 7 * Math.cos(a), 12 + 7 * Math.sin(a), 12 + 9.4 * Math.cos(a), 12 + 9.4 * Math.sin(a)); }
            break;
        case "moon":
            c.beginPath(); c.arc(12, 12, 7.5, 0.25 * Math.PI, 1.55 * Math.PI); c.bezierCurveTo(9, 9, 12, 17, 17.3, 17.3); c.stroke(); break;
        case "snow":
            cloud(); dot(8, 19, 0.9); dot(12, 20, 0.9); dot(16, 19, 0.9); break;
        case "cpu":
            box(6, 6, 12, 12, 1); box(9.5, 9.5, 5, 5, 0.3);
            for (const v of [9, 12, 15]) { line(v, 3, v, 6); line(v, 18, v, 21); line(3, v, 6, v); line(18, v, 21, v); }
            break;
        case "mem":
            box(2.5, 7, 19, 9, 1); for (const v of [6, 9, 12, 15, 18]) line(v, 16, v, 18.5); box(5.5, 10, 3, 3, 0.2); box(10.5, 10, 3, 3, 0.2); box(15.5, 10, 3, 3, 0.2); break;
        case "temp":
            c.beginPath(); c.moveTo(10, 4.5); c.lineTo(10, 13.6); c.arc(12, 17, 3.8, 1.3 * Math.PI, 1.7 * Math.PI, true); c.lineTo(14, 4.5); c.arc(12, 4.5, 2, 0, Math.PI, true); c.stroke();
            dot(12, 17, 1.7); line(12, 9, 12, 16); break;
        case "speaker": case "mute":
            shape(3, 9.5, 7, 9.5, 12, 5.5, 12, 18.5, 7, 14.5, 3, 14.5); c.stroke();
            if (name === "mute") { line(16, 9.5, 21, 14.5); line(21, 9.5, 16, 14.5); }
            else { c.beginPath(); c.arc(12, 12, 4.4, -0.3 * Math.PI, 0.3 * Math.PI); c.stroke(); c.beginPath(); c.arc(12, 12, 8, -0.3 * Math.PI, 0.3 * Math.PI); c.stroke(); }
            break;
        case "battery":
            box(6.5, 5, 11, 16, 1.5); line(10, 2.8, 14, 2.8); break;
        case "bolt":
            shape(13, 3, 6.5, 13.5, 11.5, 13.5, 10.5, 21, 17.5, 10, 12.5, 10); c.fill(); break;
        case "shuffle":
            line(3, 7, 7, 7, 15, 17, 20, 17); line(17.5, 14.5, 20, 17, 17.5, 19.5);
            line(3, 17, 7, 17, 9, 14.5); line(13, 9.5, 15, 7, 20, 7); line(17.5, 4.5, 20, 7, 17.5, 9.5); break;
        case "repeat":
            line(17, 3.5, 20, 6.5, 17, 9.5); line(20, 6.5, 8, 6.5, 4.5, 10, 4.5, 12);
            line(7, 14.5, 4, 17.5, 7, 20.5); line(4, 17.5, 16, 17.5, 19.5, 14, 19.5, 12); break;
        case "prev":
            c.fillRect(5, 5.5, 2.4, 13); shape(19, 5.5, 19, 18.5, 9, 12); c.fill(); break;
        case "next":
            c.fillRect(16.6, 5.5, 2.4, 13); shape(5, 5.5, 5, 18.5, 15, 12); c.fill(); break;
        case "pause":
            c.fillRect(6.5, 4.5, 3.6, 15); c.fillRect(13.9, 4.5, 3.6, 15); break;
        case "play":
            shape(7, 4.5, 7, 19.5, 19, 12); c.fill(); break;
        case "mail":
            box(2.5, 5.5, 19, 13, 1); line(3, 6.5, 12, 13, 21, 6.5); break;
        case "edit":
            line(11, 4.5, 4.5, 4.5, 4.5, 19.5, 19.5, 19.5, 19.5, 13); shape(18.5, 3, 21, 5.5, 12, 14.5, 9, 15, 9.5, 12); c.stroke(); break;
        case "folder":
            shape(2.5, 6, 9, 6, 11, 8.5, 21.5, 8.5, 21.5, 19, 2.5, 19); c.stroke(); break;
        case "wifi":
            for (const r of [4.5, 8.5, 12.5]) { c.beginPath(); c.arc(12, 18.5, r, 1.25 * Math.PI, 1.75 * Math.PI); c.stroke(); }
            dot(12, 18.5, 1.3); break;
        case "wifi-off":
            c.globalAlpha = 0.45;
            for (const r of [4.5, 8.5, 12.5]) { c.beginPath(); c.arc(12, 18.5, r, 1.25 * Math.PI, 1.75 * Math.PI); c.stroke(); }
            c.globalAlpha = 1; dot(12, 18.5, 1.3); line(4, 5, 20, 20); break;
        case "wired":
            box(8.5, 3.5, 7, 5.5, 0.6); line(12, 9, 12, 13); line(5, 17, 5, 13, 19, 13, 19, 17); box(2.5, 17, 5, 4, 0.5); box(16.5, 17, 5, 4, 0.5); break;
        case "power":
            line(12, 3, 12, 11); c.beginPath(); c.arc(12, 13, 7.5, -0.28 * Math.PI, 1.28 * Math.PI); c.stroke(); break;
        case "aperture":
            ring(12, 12, 9);
            for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3, b = a + 2.2; line(12 + 9 * Math.cos(a), 12 + 9 * Math.sin(a), 12 + 4.6 * Math.cos(b), 12 + 4.6 * Math.sin(b)); }
            break;
        case "search":
            ring(10.5, 10.5, 6); line(15, 15, 20.5, 20.5); break;
        case "bell":
            c.beginPath(); c.moveTo(4.5, 17.5); c.lineTo(6.5, 14.5); c.lineTo(6.5, 10); c.arc(12, 10, 5.5, Math.PI, 0); c.lineTo(17.5, 14.5); c.lineTo(19.5, 17.5); c.closePath(); c.stroke();
            line(10.3, 20.3, 13.7, 20.3); break;
        }
    }
}
