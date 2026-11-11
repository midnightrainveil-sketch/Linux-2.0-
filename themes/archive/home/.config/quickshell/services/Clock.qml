pragma Singleton

import QtQuick
import Quickshell

// Time plus the "catalogue numbers mean something" helpers from section 13.
Singleton {
    id: root

    readonly property date now: clock.date

    readonly property string hours:   pad(clock.hours, 2)
    readonly property string minutes: pad(clock.minutes, 2)

    // Wed, 27 Nov 2024
    readonly property string longDate: Qt.formatDate(now, "ddd, d MMM yyyy")
    // Wed 27 Nov 14:26 (bar)
    readonly property string barDate:  Qt.formatDateTime(now, "ddd d MMM hh:mm")

    readonly property int dayOfYear: dayOfYearOf(now)
    readonly property int week:      isoWeek(now)
    readonly property int year:      now.getFullYear()

    // Time Record: two-digit year + day of the year, e.g. 13 Oct 2026 -> 26286
    readonly property string timeRecordNo: pad(year % 100, 2) + pad(dayOfYear, 3)
    // Plate header: week of the year in Roman numerals, e.g. Tab. XLII
    readonly property string tabNumeral: roman(week)
    // Stamp year, e.g. MMXXVI
    readonly property string yearNumeral: roman(year)

    function pad(n: int, width: int): string {
        let s = String(n);
        while (s.length < width) s = "0" + s;
        return s;
    }

    function dayOfYearOf(d: date): int {
        const start = new Date(d.getFullYear(), 0, 0);
        const diff = (d - start) + (start.getTimezoneOffset() - d.getTimezoneOffset()) * 60000;
        return Math.floor(diff / 86400000);
    }

    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dayNum = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dayNum);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    function roman(n: int): string {
        const table = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
                       [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [v, s] of table) {
            while (n >= v) { out += s; n -= v; }
        }
        return out;
    }

    // 51.5874° N, 0.1278° W
    function coordinates(lat: real, lon: real): string {
        return Math.abs(lat).toFixed(4) + "° " + (lat >= 0 ? "N" : "S") + ", "
             + Math.abs(lon).toFixed(4) + "° " + (lon >= 0 ? "E" : "W");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
