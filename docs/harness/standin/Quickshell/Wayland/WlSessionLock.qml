import QtQml
QtObject {
    id: l
    property bool locked: false
    default property QtObject surface
    onLockedChanged: if (surface) surface._visible = locked
}
