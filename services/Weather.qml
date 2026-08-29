pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    readonly property string helperPath: Environment.script("weather-state.py")
    property bool ready: false
    property bool loading: false
    property bool available: false
    property string status: Settings.weatherEnabled ? "WAITING FOR FORECAST" : "WEATHER DISABLED"
    property string location: Settings.weatherLocation
    property string country: ""
    property real latitude: NaN
    property real longitude: NaN
    property string unitSymbol: Settings.temperatureUnit === "fahrenheit" ? "°F" : "°C"
    property string windUnit: Settings.temperatureUnit === "fahrenheit" ? "mph" : "km/h"
    property string timezone: ""
    property string updated: ""
    property var current: ({})
    property var hourly: []
    property var daily: []

    function applySnapshot(data) {
        available = data.ok === true;
        status = data.status || (available ? "FORECAST SYNCHRONIZED" : "FORECAST UNAVAILABLE");
        location = data.location || Settings.weatherLocation;
        country = data.country || "";
        latitude = isFinite(Number(data.latitude)) ? Number(data.latitude) : NaN;
        longitude = isFinite(Number(data.longitude)) ? Number(data.longitude) : NaN;
        unitSymbol = data.unit_symbol || unitSymbol;
        windUnit = data.wind_unit || windUnit;
        timezone = data.timezone || "";
        updated = data.updated || "";
        current = data.current || {};
        hourly = data.hourly || [];
        daily = data.daily || [];
        ready = true;
    }

    function refresh() {
        if (!Settings.weatherEnabled) {
            status = "WEATHER DISABLED";
            return;
        }
        if (!Settings.weatherLocation.trim() || weatherProcess.running)
            return;
        loading = true;
        weatherProcess.command = ["python3", helperPath,
            Settings.weatherLocation.trim(), Settings.temperatureUnit];
        weatherProcess.running = true;
    }

    property Process weatherProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applySnapshot(JSON.parse(text));
                } catch (error) {
                    root.available = false;
                    root.status = "FORECAST DECODE FAILURE";
                    console.warn("[Astralith/Weather] Decode failed:", error);
                }
            }
        }
        onRunningChanged: {
            if (!running)
                root.loading = false;
        }
    }

    property Timer refreshTimer: Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    property Timer settingsDelay: Timer {
        interval: 450
        onTriggered: root.refresh()
    }

    property Connections settingConnections: Connections {
        target: Settings
        function onWeatherEnabledChanged() { root.settingsDelay.restart(); }
        function onWeatherLocationChanged() { root.settingsDelay.restart(); }
        function onTemperatureUnitChanged() { root.settingsDelay.restart(); }
        function onPersistenceReadyChanged() {
            if (Settings.persistenceReady)
                root.settingsDelay.restart();
        }
    }
}
