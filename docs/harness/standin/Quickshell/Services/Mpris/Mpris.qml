pragma Singleton
import QtQml
QtObject {
    property MprisPlayer one: MprisPlayer {}
    property var players: ({ values: harness.playing ? [one] : [] })
}
