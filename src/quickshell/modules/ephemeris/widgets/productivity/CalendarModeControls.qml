import QtQuick
import "../../../.."

Row {
    id: controls

    required property var calendar

    spacing: 4

    Repeater {
        model: [
            { "label": "CAL", "mode": 0 },
            { "label": "HELIO", "mode": 1 },
            { "label": "EARTH", "mode": 2 }
        ]

        Rectangle {
            id: modeButton
            required property var modelData
            width: modeButton.modelData.mode === 0 ? 48 : 64
            height: 32
            radius: height / 2
            color: controls.calendar.calendarMode === modeButton.modelData.mode
                ? Theme.accent : modePointer.containsMouse ? Theme.controlHover : Theme.controlRest

            Text {
                anchors.centerIn: parent
                text: modeButton.modelData.label
                color: controls.calendar.calendarMode === modeButton.modelData.mode
                    ? Theme.void_ : Theme.moon
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Black
            }

            MouseArea {
                id: modePointer
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: controls.calendar.setCalendarMode(modeButton.modelData.mode)
            }

            Behavior on color {
                ColorAnimation { duration: Settings.motion ? 160 : 0 }
            }
        }
    }
}
