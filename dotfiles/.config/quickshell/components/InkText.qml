import QtQuick
import qs.theme

// Typed text with a faint same-colour ghost 0.4 px off, so it reads as ink
// pressed into paper rather than a crisp vector glyph.
Text {
    id: root

    property bool bleed: true
    property bool caps: false
    property real tracking: 0          // fraction of font size, e.g. 0.12

    color: Theme.soft
    font.family: Theme.typewriter
    font.pixelSize: Theme.sizeData
    font.letterSpacing: tracking * font.pixelSize
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    renderType: Text.QtRendering
    textFormat: Text.PlainText

    Text {
        visible: root.bleed
        x: 0.4
        y: 0.4
        z: -1
        width: root.width
        height: root.height
        text: root.text
        color: root.color
        opacity: 0.25
        font: root.font
        elide: root.elide
        wrapMode: root.wrapMode
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        maximumLineCount: root.maximumLineCount
        lineHeight: root.lineHeight
        renderType: root.renderType
        textFormat: root.textFormat
    }
}
