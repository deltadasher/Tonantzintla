import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    spacing: 8
        SettingChoice {
            Layout.fillWidth: true; label: "Aperture finish"; value: Settings.barMaterial
            choices: [{label: "Classic", value: "classic"}, {label: "Frosted", value: "frosted"}, {label: "Liquid glass", value: "liquid"}]
            onSelected: value => Settings.barMaterial = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Corners"; value: Settings.barCornerRadius
            choices: [{label: "Square", value: 0}, {label: "Soft", value: 6}, {label: "Round", value: 10}, {label: "Capsule", value: 26}]
            onSelected: value => Settings.barCornerRadius = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Edges"; value: Settings.barEdgeStyle
            choices: [{label: "Quiet", value: "none"}, {label: "Hairline", value: "hairline"}, {label: "Accent", value: "accent"}]
            onSelected: value => Settings.barEdgeStyle = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Workspace indicators"; value: Settings.barWorkspaceStyle
            choices: [{label: "Numbers", value: "orbital"}, {label: "Pills", value: "pills"}, {label: "Dots", value: "dots"}, {label: "Track", value: "track"}]
            onSelected: value => Settings.barWorkspaceStyle = value
        }
        SettingChoice {
            Layout.fillWidth: true; label: "Clock face"; value: Settings.barClockFace
            choices: [{label: "Classic", value: "classic"}, {label: "Stacked", value: "stacked"}, {label: "Compact", value: "compact"}, {label: "Matrix", value: "matrix"}]
            onSelected: value => Settings.barClockFace = value
        }
    }
