import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            text: "TOOLS"
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            ToolCard {
                Layout.fillWidth: true
                code: "GUIDE"
                title: "Tonantzintla manual"
                detail: "Browse modules and Compositor controls"
                onActivated: ShellState.toggleEphemeris("guide")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "SHOTS"
                title: "Screenshot tools"
                detail: "Region and full-screen capture, editing, and 60 FPS recording"
                status: Environment.canCaptureRegion ? "ONLINE" : "MISSING"
                available: Environment.canCaptureRegion
                onActivated: ShellState.toggleEphemeris("capture")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "OVERVIEW"
                title: "Compositor overview"
                detail: "Show all workspaces and windows"
                onActivated: {
                    ShellState.closeEphemeris();
                    Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                }
            }
            ToolCard {
                Layout.fillWidth: true
                code: "PICK"
                title: "Window picker"
                detail: "Open the overview before picking a window"
                onActivated: {
                    ShellState.closeEphemeris();
                    Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                }
            }
            ToolCard {
                Layout.fillWidth: true
                code: "TIMER"
                title: "Timers"
                detail: "Countdown, stopwatch, and focus timer"
                status: Timekeeper.anyRunning ? Timekeeper.activeDisplay : "READY"
                onActivated: ShellState.openQuickActions("timer")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "FOCUS"
                title: "Focus timer"
                detail: "Persistent focus and break cycles, seven-day totals, and streaks"
                status: Focus.running ? Focus.displayTime : Focus.phaseLabel
                onActivated: ShellState.toggleEphemeris("focus")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "SYSTEM"
                title: "System monitor"
                detail: "Temperatures, memory, storage, network, and uptime"
                status: SysStats.cpuTemperature > 0 ? SysStats.cpuTemperature + "°C" : "ONLINE"
                onActivated: ShellState.toggleEphemeris("system")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "POWER"
                title: "Battery details"
                detail: "Battery health, wattage, capacity, and power mode"
                status: DeviceState.batteryAvailable ? DeviceState.batteryPercent + "%"
                    : DeviceState.powerProfileAvailable ? DeviceState.powerProfile.toUpperCase() : "DESKTOP"
                onActivated: ShellState.toggleEphemeris("battery")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "STATS"
                title: "System stats"
                detail: "Open the compact system monitor"
                status: SysStats.cpuPercent + "% CPU"
                onActivated: ShellState.openQuickActions("telemetry")
            }
            ToolCard {
                Layout.fillWidth: true
                code: "SCREEN"
                title: "Capture screen"
                detail: "Save a timestamped full-screen image"
                status: Environment.canCaptureScreen ? "ONLINE" : "MISSING"
                available: Environment.canCaptureScreen
                onActivated: { ShellState.closeEphemeris(); Environment.captureScreen(); }
            }
            ToolCard {
                Layout.fillWidth: true
                code: "LOCK"
                title: "Lock session"
                detail: "Lock the screen"
                status: Umbra.secure ? "SECURED" : "READY"
                onActivated: {
                    ShellState.closeEphemeris();
                    Umbra.launchLock();
                }
            }
            ToolCard {
                Layout.fillWidth: true
                code: "TERMINAL"
                title: "Open terminal"
                detail: "Open the terminal"
                onActivated: { ShellState.closeEphemeris(); Environment.launchTerminal(); }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
