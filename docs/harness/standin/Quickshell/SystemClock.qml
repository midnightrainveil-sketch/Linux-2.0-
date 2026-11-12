import QtQml
QtObject {
    enum Precision { Hours, Minutes, Seconds }
    property int precision: 1
    property date date: harness.now()
    readonly property int hours: date.getHours()
    readonly property int minutes: date.getMinutes()
}
