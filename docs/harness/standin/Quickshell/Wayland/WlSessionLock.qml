import QtQml
QtObject {
    id: l
    property bool locked: false
    readonly property bool secure: locked     // (the compositor holds it at once, here)
    default property QtObject surface
    onLockedChanged: if (surface) surface._visible = locked
}
