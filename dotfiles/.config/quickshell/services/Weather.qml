pragma Singleton

import QtQuick
import Quickshell

// Meteorological observation from Open-Meteo (free, no API key).
// Refreshes every 15 minutes; keeps the last good reading on failure.
Singleton {
    id: root

    property bool ready: false
    property real temperature: 0
    property real feelsLike: 0
    property int humidity: 0
    property real windSpeed: 0
    property int windDirection: 0
    property int pressure: 0          // hPa, also the card's catalogue number
    property int code: 0
    property bool isDay: true

    readonly property string condition: describe(code)
    readonly property string icon: iconFor(code, isDay)
    readonly property string windCompass: compass(windDirection)

    function describe(c: int): string {
        if (c === 0) return isDay ? "Clear" : "Clear night";
        if (c === 1) return "Mainly clear";
        if (c === 2) return "Partly cloudy";
        if (c === 3) return "Overcast";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 67) return "Rain";
        if (c >= 71 && c <= 77) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c === 85 || c === 86) return "Snow showers";
        if (c >= 95) return "Thunderstorm";
        return "Unrecorded";
    }

    function iconFor(c: int, day: bool): string {
        if (c === 0 || c === 1) return day ? "clear" : "clear-night";
        if (c === 2) return day ? "partly" : "partly-night";
        if (c === 3) return "overcast";
        if (c === 45 || c === 48) return "fog";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "rain";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
        if (c >= 95) return "storm";
        return "overcast";
    }

    function compass(deg: int): string {
        const points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return points[Math.round(((deg % 360) / 45)) % 8];
    }

    function refresh(): void {
        const url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + Settings.latitude
            + "&longitude=" + Settings.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,"
            + "wind_speed_10m,wind_direction_10m,pressure_msl,is_day"
            + "&wind_speed_unit=kmh&timezone=auto";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) {
                retry.restart();
                return;
            }
            try {
                const c = JSON.parse(xhr.responseText).current;
                root.temperature = c.temperature_2m;
                root.feelsLike = c.apparent_temperature;
                root.humidity = c.relative_humidity_2m;
                root.windSpeed = c.wind_speed_10m;
                root.windDirection = c.wind_direction_10m;
                root.pressure = Math.round(c.pressure_msl);
                root.code = c.weather_code;
                root.isDay = c.is_day === 1;
                root.ready = true;
            } catch (e) {
                console.warn("archive: weather parse failed", e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Retry sooner after a failure (e.g. no network right after boot).
    Timer {
        id: retry
        interval: 60 * 1000
        onTriggered: root.refresh()
    }

    Connections {
        target: Settings
        function onLatitudeChanged() { root.refresh(); }
        function onLongitudeChanged() { root.refresh(); }
    }
}
