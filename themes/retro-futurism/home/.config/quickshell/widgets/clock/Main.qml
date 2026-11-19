import QtQuick
import qs.components

// Clock: not built yet; its mock-up stands in (art/ClockWidget.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "clock"
    preferredWidth: 1247
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Clock"
        picture: self.art("preview.jpg")
    }
}
