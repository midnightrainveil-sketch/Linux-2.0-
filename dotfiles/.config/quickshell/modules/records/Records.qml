import QtQuick
import qs.theme
import qs.services
import qs.components

// The record cards: Time, Meteorological and Audio, stacked down the right
// of the sheet at login. They lie on the sheet (bottom layer), so working
// windows cover them, and take no space from them. Each can be dragged
// anywhere on the sheet or filed away with a right click; the bar's desk
// button (archive-desk, Super+D) lays them all back. On the G14's 16:10
// panel the extra height goes into breathing room between the cards.
//
// They are drawn on the sheet itself (Plate.qml places this over the whole
// sheet above the bar): one full-screen surface fewer to keep and to
// composite than a window of their own, and they lie under working windows
// all the same.
Item {
    id: win

    required property var modelData

    // the reference is 1080 px tall; extra height (the G14 is 16:10) becomes
    // a little more air between the cards, never another card
    readonly property real extra: Math.max(0, height - 1080 + Theme.barHeight)
    readonly property real column: width - Theme.margin - Theme.recordWidth
    readonly property real gap: Theme.cardGap + extra * 0.2

    // over the cards the lamp keeps following
    HoverHandler {
        onPointChanged: if (hovered && Lamp.isOn && Theme.night > 0.5) Lamp.moveTo(win.modelData?.name ?? "", point.position.x, point.position.y)
    }

    DeskCard {
        id: time
        name: "time"
        wanted: Settings.showTime
        width: Theme.recordWidth
        homeX: win.column
        homeY: Theme.recordTop + win.extra * 0.15
        TimeRecord { width: parent.width }
    }
    DeskCard {
        id: weather
        name: "weather"
        wanted: Settings.showWeather
        width: Theme.recordWidth
        homeX: win.column
        homeY: Settings.showTime ? time.homeY + time.height + win.gap : time.homeY
        WeatherRecord { width: parent.width }
    }
    DeskCard {
        id: audio
        name: "audio"
        wanted: Settings.showAudio
        width: Theme.recordWidth
        homeX: win.column
        homeY: Settings.showWeather ? weather.homeY + weather.height + win.gap : weather.homeY
        AudioRecord { width: parent.width }
    }

    // the desk lamp's light, over the sheet and the cards alike (night only)
    LampLight {
        anchors.fill: parent
        z: 100
        screenName: win.modelData?.name ?? ""
    }
}
