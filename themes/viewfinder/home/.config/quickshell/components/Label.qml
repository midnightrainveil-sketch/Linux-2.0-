import QtQuick
import qs.theme

// One line of type: monospaced, small capitals by default.
Text {
    property bool caps: true
    property real tracking: 1.2
    color: Theme.ink
    font.family: Theme.mono
    font.pixelSize: 15
    font.letterSpacing: tracking
    font.capitalization: caps ? Font.AllUppercase : Font.MixedCase
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
