import QtQuick
import qs.theme
import qs.services
import qs.components

// Ledger (calendar): rises from the bar's date. Month pages typed in
// Courier, week numbers in the first column, today circled in a blue pencil
// ring. The pages scroll: the wheel turns one month, a touchpad slides them;
// arrow keys too, Home for today. "Year" (or F) opens the whole year's
// ledger in the middle of the desk.
BarPopup {
    id: popup
    name: "ledger"
    side: "right"

    readonly property int pageH: 6 * 30 - 2      // six weeks
    readonly property int pageGap: 16
    readonly property int shownMonth: Math.round(leaf.pos)
    readonly property date base: {
        const n = Clock.now;
        return new Date(n.getFullYear(), n.getMonth() + shownMonth, 1);
    }

    function enlarge(): void {
        Panels.ledgerAt = popup.leaf.target;
        Panels.show("ledger-year");
    }

    property alias leaf: leaf
    Leafing { id: leaf; page: popup.pageH * 0.6 }

    onOpened: {
        leaf.jump(Panels.ledgerAt);
        Panels.ledgerAt = 0;
        keys.forceActiveFocus();
    }

    IndexCard {
        id: card
        width: 360
        title: "Ledger"
        subtitle: Qt.formatDate(popup.base, "MMMM yyyy") + "."
        number: Clock.pad(popup.base.getMonth() + 1, 2) + String(popup.base.getFullYear()).slice(2)
        seed: 505
        lift: 1.4

        SheetMark {
            parent: card
            x: card.width - Theme.headerPadH - width
            y: 34
            word: "Year"
            enlarge: true
            onClicked: popup.enlarge()
        }

        Item {
            id: keys
            width: parent.width
            height: 12 + 26 + popup.pageH + 14
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_PageUp) leaf.step(-1);
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_PageDown) leaf.step(1);
                else if (e.key === Qt.Key_Home || e.key === Qt.Key_T) leaf.to(0);
                else if (e.key === Qt.Key_F || e.key === Qt.Key_Y) popup.enlarge();
                else if (e.key === Qt.Key_Escape) Panels.close();
            }
            WheelHandler { onWheel: e => leaf.wheel(e) }

            readonly property int cw: (card.width - 2 * Theme.headerPadH + 8) / 8

            // the weekdays stay put; the months scroll under them
            Row {
                id: weekdays
                x: Theme.headerPadH - 4
                y: 12
                Repeater {
                    model: ["Wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Item {
                        required property string modelData
                        required property int index
                        width: keys.cw; height: 24
                        InkText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.sizeLabel
                            color: index === 0 ? Theme.faded : Theme.soft
                            font.bold: index !== 0
                        }
                    }
                }
            }

            Item {
                id: window_
                x: weekdays.x
                y: weekdays.y + 26
                width: 8 * keys.cw
                height: popup.pageH
                clip: true

                // three pages at most are ever in sight: the one before, this
                // one, the one after
                Repeater {
                    model: [-1, 0, 1]
                    Item {
                        id: page
                        required property int modelData
                        readonly property int month: Math.floor(leaf.pos) + modelData
                        y: (month - leaf.pos) * (popup.pageH + popup.pageGap)
                        width: window_.width
                        height: popup.pageH
                        visible: y > -height - popup.pageGap && y < window_.height + popup.pageGap

                        MonthGrid {
                            first: new Date(Clock.now.getFullYear(), Clock.now.getMonth() + page.month, 1)
                            cellW: keys.cw
                            cellH: 28
                            seed: 510
                        }
                        // the ruled line between two months
                        Rule {
                            y: popup.pageH + popup.pageGap / 2 - height / 2
                            width: parent.width
                            height: implicitHeight
                            color: Theme.ruleFaint
                            weight: 1
                            seed: 530 + page.month
                        }
                    }
                }
            }
        }
    }
}
