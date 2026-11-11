import QtQuick
import qs.theme

// Typed text with a faint same-colour ghost 0.4 px off, so it reads as ink
// pressed into paper rather than a crisp vector glyph.
Text {
    id: root

    property bool bleed: true
    // how far the ink spreads into the paper, in px; the reference's typed
    // text reads a little heavier than the bare glyphs
    property real spread: 0.5
    property bool caps: false
    property real tracking: 0          // fraction of font size, e.g. 0.12

    color: Theme.soft
    font.family: Theme.typewriter
    font.pixelSize: Theme.sizeData
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    renderType: Text.QtRendering
    textFormat: Text.PlainText

    // tracking is set once, not bound: font is one grouped property, so a
    // binding from font.pixelSize to font.letterSpacing would loop
    function applyTracking() {
        if (tracking !== 0 || font.letterSpacing !== 0)
            font.letterSpacing = tracking * font.pixelSize;
    }
    onTrackingChanged: applyTracking()
    Component.onCompleted: applyTracking()

    component Ghost: Text {
        visible: root.bleed
        z: -1
        width: root.width
        height: root.height
        text: root.text
        color: root.color
        font: root.font
        elide: root.elide
        wrapMode: root.wrapMode
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        maximumLineCount: root.maximumLineCount
        lineHeight: root.lineHeight
        renderType: root.renderType
        textFormat: root.textFormat
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        topPadding: root.topPadding
        bottomPadding: root.bottomPadding
    }
    Ghost { x: root.spread * 0.9; y: root.spread * 0.4; opacity: 0.42 }
    Ghost { x: -root.spread * 0.3; y: root.spread * 0.8; opacity: 0.30 }
}
