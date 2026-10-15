import QtQuick
import qs.theme
import qs.services
import qs.components

// The Ledger enlarged: the whole year on one sheet in the middle of the
// desk, twelve months in four columns. The years scroll like the months do
// on the small card (wheel, touchpad, arrow keys, Home). Click a month to
// open it on the small card; "Month" (or F) goes back to the one you were on.
BarPopup {
    id: popup
    name: "ledger-year"
    side: "middle"

    readonly property int cellW: 30
    readonly property int cellH: 24
    readonly property int monthW: 8 * cellW
    readonly property int monthH: 26 + (cellH - 4) + 2 + 6 * (cellH + 2)
    readonly property int colGap: 44
    readonly property int rowGap: 22
    readonly property int pageH: 3 * monthH + 2 * rowGap
    readonly property int pageGap: 30

    readonly property int shownYear: Clock.now.getFullYear() + Math.round(leaf.pos)
    property int fromMonth: 0                 // the month the small card was on

    Leafing { id: leaf; page: popup.pageH * 0.5 }

    onOpened: {
        fromMonth = Panels.ledgerAt;
        Panels.ledgerAt = 0;
        const m = Clock.now.getMonth() + fromMonth;
        leaf.jump(Math.floor(m / 12));
        keys.forceActiveFocus();
    }

    // back to the small card, at month m (months from this one)
    function reduce(m: int): void {
        Panels.ledgerAt = m;
        Panels.show("ledger");
    }
    function backToMonth(): void {
        // the month we came from if it is in the year shown, else its January
        const now = Clock.now;
        const fromYear = Math.floor((now.getMonth() + fromMonth) / 12);
        reduce(fromYear === leaf.target ? fromMonth : 12 * leaf.target - now.getMonth());
    }

    IndexCard {
        id: card
        width: 2 * 40 + 4 * popup.monthW + 3 * popup.colGap
        title: "Ledger"
        subtitle: "The year " + popup.shownYear + ", in full."
        number: String(popup.shownYear)
        seed: 507
        lift: 1.6

        SheetMark {
            parent: card
            x: card.width - Theme.headerPadH - width
            y: 34
            word: "Month"
            enlarge: false
            onClicked: popup.backToMonth()
        }

        Item {
            id: keys
            width: parent.width
            height: 18 + popup.pageH + 24
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_PageUp) leaf.step(-1);
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_PageDown) leaf.step(1);
                else if (e.key === Qt.Key_Home || e.key === Qt.Key_T) leaf.to(0);
                else if (e.key === Qt.Key_F || e.key === Qt.Key_Y || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) popup.backToMonth();
                else if (e.key === Qt.Key_Escape) Panels.close();
            }
            WheelHandler { onWheel: e => leaf.wheel(e) }

            Item {
                id: window_
                x: 40
                y: 18
                width: parent.width - 80
                height: popup.pageH
                clip: true

                Repeater {
                    model: [-1, 0, 1]
                    Item {
                        id: page
                        required property int modelData
                        readonly property int yearsOn: Math.floor(leaf.pos) + modelData
                        readonly property int year: Clock.now.getFullYear() + yearsOn
                        y: (yearsOn - leaf.pos) * (popup.pageH + popup.pageGap)
                        width: window_.width
                        height: popup.pageH
                        visible: y > -height - popup.pageGap && y < window_.height + popup.pageGap

                        Repeater {
                            model: 12
                            Item {
                                id: month
                                required property int index
                                readonly property bool current: page.year === Clock.now.getFullYear() && index === Clock.now.getMonth()
                                x: (index % 4) * (popup.monthW + popup.colGap)
                                y: Math.floor(index / 4) * (popup.monthH + popup.rowGap)
                                width: popup.monthW
                                height: popup.monthH

                                InkText {
                                    id: monthName
                                    x: popup.cellW + 4
                                    y: 2
                                    text: Qt.formatDate(new Date(page.year, month.index, 1), "MMMM")
                                    caps: true
                                    tracking: Theme.trackTitle
                                    font.pixelSize: Theme.sizeSmall
                                    color: month.current ? Theme.accent
                                         : pick.containsMouse ? Theme.graphite : Theme.soft
                                }
                                InkText {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    y: 3
                                    text: Clock.pad(month.index + 1, 2)
                                    font.pixelSize: Theme.sizeSmall - 2
                                    color: Theme.faded
                                }
                                // pencilled under the name while the pointer is on the month
                                Rule {
                                    x: monthName.x - 2
                                    y: monthName.y + monthName.height + 1
                                    width: monthName.width + 6
                                    height: implicitHeight
                                    weight: 1
                                    color: Theme.accent
                                    opacity: pick.containsMouse ? 0.8 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }
                                    seed: 560 + month.index
                                }

                                MonthGrid {
                                    y: 26
                                    first: new Date(page.year, month.index, 1)
                                    weekdays: ["", "M", "T", "W", "T", "F", "S", "S"]
                                    cellW: popup.cellW
                                    cellH: popup.cellH
                                    fontSize: Theme.sizeSmall
                                    weekSize: Theme.sizeSmall - 2
                                    seed: 600 + month.index * 50
                                }

                                MouseArea {
                                    id: pick
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const now = Clock.now;
                                        popup.reduce((page.year - now.getFullYear()) * 12 + month.index - now.getMonth());
                                    }
                                }
                            }
                        }

                        Rule {
                            y: popup.pageH + popup.pageGap / 2 - height / 2
                            width: parent.width
                            height: implicitHeight
                            color: Theme.ruleFaint
                            weight: 1
                            seed: 540 + page.yearsOn
                        }
                    }
                }
            }
        }
    }
}
