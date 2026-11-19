import QtQuick
import qs.components

// Power: not built yet; its mock-up stands in (art/Power.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "power"
    preferredWidth: 780
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Power"
        picture: self.art("preview.jpg")
    }
}
