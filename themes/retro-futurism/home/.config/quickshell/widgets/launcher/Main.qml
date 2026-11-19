import QtQuick
import qs.components

// App launcher: not built yet; its mock-up stands in (art/AppLauncher.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "launcher"
    preferredWidth: 1247
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "App launcher"
        picture: self.art("preview.jpg")
    }
}
