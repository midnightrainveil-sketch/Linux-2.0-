import QtQuick
import qs.components

// Cassette player: not built yet; its mock-up stands in (art/CassettePlayerWidget.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "cassette"
    preferredWidth: 1247
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Cassette player"
        picture: self.art("preview.jpg")
    }
}
