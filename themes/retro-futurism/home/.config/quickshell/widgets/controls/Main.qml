import QtQuick
import qs.components

// Control deck: not built yet; its mock-up stands in (art/ControlDeck.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "controls"
    preferredWidth: 1386
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Control deck"
        picture: self.art("preview.jpg")
    }
}
