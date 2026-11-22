import QtQuick

// One card of a split-flap board: shows ch, and when ch changes flips to it
// as the real ones do, card by card through the cards between (only the
// last few, so it stays quick): the top half of the card that was there
// folds down over the middle, the bottom half of the next one comes down
// after it.
//
//   FlapTile { ch: "7"; width: 40; height: 56; size: 44 }
Item {
    id: tile

    property string ch: " "
    property real size: height * 0.78                 // the letters
    property color ink: "#f3ead8"
    property color card: "#1d1a18"
    property string face: "Barlow"
    property int flipMs: 70

    // the drum: the cards in order; anything else shows as a blank
    readonly property string drum: " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:.-/%+&'"
    function norm(c: string): string {
        const u = (c || " ").toUpperCase().charAt(0);
        return drum.indexOf(u) >= 0 ? u : " ";
    }

    property string cur: " "                          // the card showing
    property string next: " "                         // the one coming down
    Component.onCompleted: { cur = norm(ch); next = cur; }
    property bool flipping: false
    onChChanged: if (!flipping) step()

    function step(): void {
        const want = norm(ch);
        if (want === cur) { flipping = false; return; }
        const n = drum.length, a = drum.indexOf(cur), b = drum.indexOf(want);
        const gap = (b - a + n) % n;
        // the cards between: all of them when few, else the last three
        next = gap <= 4 ? drum.charAt((a + 1) % n) : drum.charAt((b - 3 + n) % n);
        flipping = true;
        flip.restart();
    }

    component Half: Item {
        property string glyph: " "
        property bool lower: false
        width: tile.width; height: tile.height / 2
        clip: true
        Rectangle {
            y: parent.lower ? -tile.height / 2 : 0
            width: tile.width; height: tile.height; radius: Math.max(1, tile.width * 0.08)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(tile.card, 1.35) }
                GradientStop { position: 0.5; color: tile.card }
                GradientStop { position: 1.0; color: Qt.darker(tile.card, 1.25) }
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: tile.size * 0.03
                text: parent.parent.glyph
                color: tile.ink
                font.family: tile.face; font.weight: Font.DemiBold
                font.pixelSize: tile.size
            }
        }
    }

    // what stays still: the next card's top, the current card's bottom
    Half { glyph: tile.next }
    Half { y: tile.height / 2; lower: true; glyph: tile.cur }
    // the flaps: the current top folding down, then the next bottom
    Half {
        id: foldTop
        glyph: tile.cur
        visible: tile.flipping
        transform: Scale { id: topScale; origin.y: tile.height / 2; yScale: 1 }
        Rectangle { anchors.fill: parent; color: "black"; opacity: (1 - topScale.yScale) * 0.5 }
    }
    Half {
        id: foldBottom
        y: tile.height / 2; lower: true
        glyph: tile.next
        visible: tile.flipping && bottomScale.yScale > 0
        transform: Scale { id: bottomScale; origin.y: 0; yScale: 0 }
        Rectangle { anchors.fill: parent; color: "black"; opacity: (1 - bottomScale.yScale) * 0.4 }
    }
    // the gap between the halves
    Rectangle { y: tile.height / 2 - 0.5; width: tile.width; height: Math.max(1, tile.height * 0.025); color: "#000000"; opacity: 0.7 }

    SequentialAnimation {
        id: flip
        ScriptAction { script: { topScale.yScale = 1; bottomScale.yScale = 0; } }
        NumberAnimation { target: topScale; property: "yScale"; to: 0; duration: tile.flipMs / 2; easing.type: Easing.InQuad }
        NumberAnimation { target: bottomScale; property: "yScale"; to: 1; duration: tile.flipMs / 2; easing.type: Easing.OutQuad }
        ScriptAction { script: { tile.cur = tile.next; tile.step(); } }
    }
}
