import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// The right record column: stacked Time, Meteorological and Audio cards.
// It lies on the sheet (bottom layer), so working windows cover it, and it
// takes no space from them. On the G14's 16:10 panel the extra height goes
// into breathing room between the cards, never into a fourth card.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property int pad: 24
    anchors { top: true; right: true; bottom: true }
    margins.right: Theme.margin - pad
    margins.bottom: Theme.barHeight
    implicitWidth: Theme.recordWidth + 2 * pad
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "archive-records"
    color: "transparent"
    mask: Region { item: column }

    readonly property real cardsHeight: time.height + weather.height + audio.height
    readonly property int count: (time.visible ? 1 : 0) + (weather.visible ? 1 : 0) + (audio.visible ? 1 : 0)
    readonly property real free: height - 2 * Theme.margin - cardsHeight - 40

    Column {
        id: column
        x: win.pad
        y: Theme.margin + 16 + Math.max(0, win.free * 0.08)
        width: Theme.recordWidth
        spacing: Math.max(Theme.cardGap, Math.min(56, win.free * 0.35 / Math.max(1, win.count - 1)))

        TimeRecord { id: time; width: parent.width; visible: Settings.showTime }
        WeatherRecord { id: weather; width: parent.width; visible: Settings.showWeather }
        AudioRecord { id: audio; width: parent.width; visible: Settings.showAudio }
    }
}
