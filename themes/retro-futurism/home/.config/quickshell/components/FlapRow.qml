import QtQuick

// A row of split-flap cards spelling text, padded or cut to its length.
//
//   FlapRow { text: "DESKTOP SESSION"; length: 15; cell: 15; cellHeight: 22 }
Row {
    id: row

    property string text: ""
    property int length: 10
    property real cell: 14                    // a card's width
    property real cellHeight: 20
    property color ink: "#f3ead8"
    property color card: "#2e2a27"            // the small cards a shade lighter than the board
    property int align: Text.AlignLeft        // where a short text sits
    spacing: Math.max(1, cell * 0.12)

    readonly property string padded: {
        const t = text.toUpperCase().slice(0, length);
        const gap = length - t.length;
        if (align === Text.AlignRight) return " ".repeat(gap) + t;
        if (align === Text.AlignHCenter) return " ".repeat(Math.floor(gap / 2)) + t + " ".repeat(Math.ceil(gap / 2));
        return t + " ".repeat(gap);
    }
    Repeater {
        model: row.length
        FlapTile {
            required property int index
            width: row.cell; height: row.cellHeight
            ink: row.ink
            card: row.card
            ch: row.padded.charAt(index)
        }
    }
}
