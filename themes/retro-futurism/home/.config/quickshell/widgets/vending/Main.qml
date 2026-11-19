import QtQuick
import qs.components

// Cassette vending: not built yet; its mock-up stands in (art/CassetteVending.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "vending"
    preferredWidth: 624
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Cassette vending"
        picture: self.art("preview.jpg")
    }
}
