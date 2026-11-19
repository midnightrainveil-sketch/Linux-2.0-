import QtQuick
import Quickshell
import qs.services

// What every widget is built on. A widget's file (widgets/<id>/Main.qml)
// is one of these with its own parts inside:
//
//   Widget {
//       widgetId: "typewriter"
//       preferredWidth: 1100; preferredHeight: 760    // its size on a 1920-wide screen
//       Image { anchors.fill: parent; source: art("typewriter.png") }
//       Keys.onPressed: e => { ... }                 // it has the keyboard while up
//   }
//
// It is given:
//   store            its saved state (WidgetStore: get / set)
//   art(name)        a picture in its own folder
//   close()          put it away (Esc and a click outside also do)
//   shown            true while up; false as it goes (to stop timers, sounds)
//   opened()         after it has come up; closing() as it starts to go
// The stage (modules/WidgetStage.qml) sizes it to fit the screen, animates it
// in and out, and blurs and dims what lies behind.
FocusScope {
    id: widget

    required property string widgetId
    property real preferredWidth: 900
    property real preferredHeight: 600
    // the clear margin (a shadow, air) round its body on the right and below,
    // so the stage lines the body itself up (with the taskbar's end)
    property real airRight: 0
    property real airBottom: 0
    property bool shown: false

    signal opened()
    signal closing()

    readonly property WidgetStore store: WidgetStore { widgetId: widget.widgetId }
    function art(name: string): string { return Quickshell.shellPath("widgets/" + widgetId + "/" + name); }
    function close(): void { Widgets.close(); }

    width: preferredWidth
    height: preferredHeight
    focus: true
    // Esc puts it away, unless the widget takes it first: escapeHandler, if
    // set, is called and returns true when it used the key (to leave an edit)
    property var escapeHandler: null
    Keys.onEscapePressed: if (!(escapeHandler && escapeHandler())) close()
}
