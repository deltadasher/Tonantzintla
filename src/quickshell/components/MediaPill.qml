import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Rectangle {

    property bool embedded: false
    implicitWidth: Media.available ? (Settings.compact ? 320 : 400) : 0
    implicitHeight: Settings.compact ? 36 : 42
    radius: embedded ? 9 : height / 2
    color: embedded ? "transparent"
        : mediaHover.hovered ? Theme.elevated : Theme.mantle
    border.width: 0
    opacity: Media.available ? 1 : 0
    clip: true

    HoverHandler {
        id: mediaHover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton)
                Media.next();
            else if (mouse.button === Qt.RightButton)
                Media.raise();
            else
                ShellState.toggleEphemeris("media");
        }
        onWheel: function(event) {
            if (event.angleDelta.y > 0)
                Media.previous();
            else
                Media.next();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: embedded ? 0 : 5
        anchors.rightMargin: embedded ? 0 : 6
        spacing: 8

        Rectangle {
            Layout.preferredWidth: Settings.compact ? 30 : 36
            Layout.preferredHeight: Layout.preferredWidth
            radius: Settings.compact ? 8 : 9
            color: Theme.elevated
            border.width: 0
            clip: true

            Image {
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: Media.artUrl.length > 0
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.accent
                opacity: Media.playing ? 0.06 : 0.14
            }
            Text {
                anchors.centerIn: parent
                visible: Media.artUrl.length === 0
                text: Media.mediaKind === "VIDEO" ? "▻" : "♪"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Settings.compact ? 13 : 15
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: 7
                height: 7
                radius: 4
                color: Media.playing ? Theme.success : Theme.warning

                SequentialAnimation on opacity {
                    running: Media.playing && Settings.motion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 850; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 850; easing.type: Easing.InOutSine }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: Media.title
                color: Theme.moon
                font.family: Theme.fontText
                font.pixelSize: Settings.compact ? 12 : 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: Settings.showMediaTime && Media.length > 0
                        ? Media.timeText : Media.artist
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: Settings.compact ? 10 : 11
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                visible: Settings.showMediaProgress && Media.length > 0
                radius: 2
                color: Theme.barNeutralHover
                clip: true

                Rectangle {
                    width: Math.max(3, parent.width * Media.progress)
                    height: parent.height
                    radius: parent.radius
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.86)

                    Behavior on width {
                        NumberAnimation {
                            duration: Settings.motion ? 700 : 0
                            easing.type: Easing.Linear
                        }
                    }
                }
            }
        }

        RowLayout {
            spacing: 1

            Repeater {
                model: [
                    { "glyph": "‹", "action": "previous" },
                    { "glyph": Media.playing ? "Ⅱ" : "▶", "action": "toggle" },
                    { "glyph": "›", "action": "next" }
                ]

                Rectangle {
                    id: control
                    required property var modelData
                    Layout.preferredWidth: control.modelData.action === "toggle" ? 36 : 30
                    Layout.preferredHeight: 36
                    radius: 10
                    color: controlPointer.containsMouse ? Theme.accentVeil : "transparent"
                    scale: controlPointer.containsMouse ? 1.10 : 1

                    Text {
                        anchors.centerIn: parent
                        text: control.modelData.glyph
                        color: controlPointer.containsMouse
                            ? (control.modelData.action === "toggle" ? Theme.success : Theme.accent)
                            : Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: control.modelData.action === "toggle" ? 19 : 20
                        font.weight: control.modelData.action === "toggle" ? Font.Bold : Font.Medium
                    }
                    MouseArea {
                        id: controlPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (control.modelData.action === "previous") Media.previous();
                            else if (control.modelData.action === "next") Media.next();
                            else Media.toggle();
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on scale { NumberAnimation { duration: Settings.motion ? 170 : 0; easing.type: Easing.OutBack } }
                }
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: Settings.motion ? Theme.motionSlow : 0; easing.type: Easing.OutQuint }
    }
    Behavior on opacity { NumberAnimation { duration: Settings.motion ? Theme.motionNormal : 0 } }
    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
}
