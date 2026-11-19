import QtQml
QtObject {
    enum Precision { Hours, Minutes, Seconds }
    property int precision: 1
    property bool enabled: true
    property date date: harness.now()
    readonly property int hours: date.getHours()
    readonly property int minutes: date.getMinutes()
    readonly property int seconds: date.getSeconds()
}
