import QtQuick
import qs.theme

// Where the ledger is open, in pages from today's, and how it moves: a click
// of the wheel (or an arrow key) turns one page with a short glide; a
// touchpad drags the pages under the fingers and lets them settle on the
// nearest. `pos` is the page shown, fractional while moving.
Item {
    id: root

    property real page: 200              // px of finger travel per page
    property real pos: 0
    property int target: 0
    property real acc: 0                 // wheel angle not yet turned into pages

    function to(n: int): void {
        settle.stop();
        target = n;
        glide.stop();
        glide.from = pos;
        glide.to = n;
        glide.start();
    }
    function step(by: int): void { to(target + by); }
    function jump(n: int): void { glide.stop(); settle.stop(); target = n; pos = n; acc = 0; }

    function wheel(e: var): void {
        if (e.pixelDelta.y !== 0) {
            glide.stop();
            pos -= e.pixelDelta.y / page;
            target = Math.round(pos);
            settle.restart();
            return;
        }
        acc += e.angleDelta.y;
        while (acc >= 120) { step(-1); acc -= 120; }
        while (acc <= -120) { step(1); acc += 120; }
    }

    NumberAnimation {
        id: glide
        target: root
        property: "pos"
        duration: Theme.dur(300)
        easing.type: Easing.OutCubic
    }
    Timer { id: settle; interval: 140; onTriggered: root.to(Math.round(root.pos)) }
}
