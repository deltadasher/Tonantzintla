import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../services"

Item {
    id: root

    function captureRegion(action) {
        ShellState.closeEphemeris();
        Environment.captureRegion(action);
    }

    function captureScreen(action) {
        ShellState.closeEphemeris();
        Environment.captureScreen(action);
    }

    component SectionLabel: ColumnLayout {
        property string title: "SCREENSHOTS"
        property string detail: "SCREENSHOTS"
        spacing: 2
        Text {
            text: parent.title
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 17
            font.weight: Font.Black
        }
        Text {
            text: parent.detail
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }

    component CaptureTile: Rectangle {
        id: tile
        property string code: "COPY"
        property string title: "Copy region"
        property string detail: "Slurp → Grim → clipboard"
        property string glyph: "󰹑"
        property bool available: true
        signal activated()

        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: Theme.radiusMedium
        color: !available ? Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.45)
            : tilePointer.containsMouse ? Theme.accentVeil : Theme.mantle
        border.width: 0
        border.color: !available ? Theme.barHairline
            : tilePointer.containsMouse ? Theme.accentLine : Theme.line
        opacity: available ? 1 : 0.52
        scale: tilePointer.containsMouse && available ? 1.015 : 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 11

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 12
                color: tilePointer.containsMouse && tile.available
                    ? Theme.barAccentVeil : Theme.elevated
                Text {
                    anchors.centerIn: parent
                    text: tile.glyph
                    color: tile.available ? Theme.accent : Theme.lineBright
                    font.family: Theme.fontIcon
                    font.pixelSize: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: tile.code
                    color: tile.available ? Theme.accent : Theme.lineBright
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                }
                Text {
                    Layout.fillWidth: true
                    text: tile.title
                    color: tile.available ? Theme.moon : Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: tile.available ? tile.detail : "BACKEND UNAVAILABLE"
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: tilePointer
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.available
            cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
            onClicked: tile.activated()
        }

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on scale { NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "SCREENSHOTS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.Black
            }

            Rectangle {
                Layout.preferredWidth: statusRow.implicitWidth + 24
                Layout.preferredHeight: 34
                radius: 10
                color: Environment.recording
                    ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.13)
                    : Theme.barNeutral
                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: Environment.recording ? Theme.danger
                            : Environment.canCaptureRegion ? Theme.success : Theme.warning
                        SequentialAnimation on opacity {
                            running: Environment.recording && Settings.motion
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 650 }
                            NumberAnimation { to: 1; duration: 650 }
                        }
                    }
                    Text {
                        text: Environment.recording ? "RECORDING LIVE"
                            : Environment.screenshotStatus
                        color: Environment.recording ? Theme.danger : Theme.moon
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                SectionLabel {
                    title: "SCREENSHOT"
                    detail: "REGION OR FULL SCREEN"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    CaptureTile {
                        code: "COPY"; title: "Copy region"; glyph: "󰆏"
                        detail: "Fast clipboard snip"
                        available: Environment.canCaptureRegion
                        onActivated: root.captureRegion("copy")
                    }
                    CaptureTile {
                        code: "SAVE"; title: "Save region"; glyph: "󰆓"
                        detail: "Save the selected area"
                        available: Environment.canCaptureRegion
                        onActivated: root.captureRegion("save")
                    }
                    CaptureTile {
                        code: "EDIT"; title: "Edit region"; glyph: "󰏫"
                        detail: "Annotate through Satty"
                        available: Environment.canEditCapture
                        onActivated: root.captureRegion("edit")
                    }
                    CaptureTile {
                        code: "OUT/COPY"; title: "Copy screen"; glyph: "󰍹"
                        detail: "Whole screen to clipboard"
                        available: Environment.canCaptureScreen && Environment.hasWlCopy
                        onActivated: root.captureScreen("copy")
                    }
                    CaptureTile {
                        code: "OUT/SAVE"; title: "Save screen"; glyph: "󰋩"
                        detail: "Timestamped PNG files"
                        available: Environment.canCaptureScreen
                        onActivated: root.captureScreen("save")
                    }
                    CaptureTile {
                        code: "OUT/EDIT"; title: "Edit screen"; glyph: "󰏫"
                        detail: "Full screen into Satty"
                        available: Environment.hasGrim && Environment.hasSatty
                        onActivated: root.captureScreen("edit")
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: Theme.radiusMedium
                    color: captureFolderPointer.containsMouse ? Theme.barNeutralHover : Theme.barNeutral
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        Text { text: "󰉋"; color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 19 }
                        Text { Layout.fillWidth: true; text: "OPEN SCREENSHOT ARCHIVE"; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                        Text { text: "~/Pictures/Screenshots"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10 }
                    }
                    MouseArea { id: captureFolderPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Environment.openCaptureFolder() }
                }
            }

            Rectangle {
                Layout.preferredWidth: 292
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: Theme.mantle
                border.width: 0
                border.color: Environment.recording ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.52) : Theme.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 13

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "SCREEN RECORDING"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 16; font.weight: Font.Black }
                            Text { text: "GPU SCREEN RECORDER"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 0.9 }
                        }
                        Rectangle {
                            Layout.preferredWidth: 11
                            Layout.preferredHeight: 11
                            radius: 6
                            color: Environment.recording ? Theme.danger
                                : Environment.canRecord ? Theme.success : Theme.warning
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 154
                        radius: Theme.radiusMedium
                        color: Environment.recording
                            ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.10)
                            : Theme.elevated

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Environment.recording ? "●" : "◉"
                                color: Environment.recording ? Theme.danger : Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: 40
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Environment.recording ? "STREAM ACTIVE" : "PORTAL READY"
                                color: Theme.moon
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.weight: Font.Black
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Environment.canRecord
                                    ? "60 FPS · H.264 · DESKTOP AUDIO" : "INSTALL GPU-SCREEN-RECORDER"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: 12
                        color: Environment.recording ? Theme.danger
                            : recordPointer.containsMouse ? Theme.accent : Theme.accentVeil
                        opacity: Environment.canRecord ? 1 : 0.45
                        Text {
                            anchors.centerIn: parent
                            text: Environment.recording ? "STOP AND FINALIZE" : "START PORTAL RECORDING"
                            color: Environment.recording ? Theme.void_ : recordPointer.containsMouse ? Theme.void_ : Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }
                        MouseArea {
                            id: recordPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: Environment.canRecord
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: {
                                if (Environment.recording)
                                    Environment.stopRecording();
                                else {
                                    ShellState.closeEphemeris();
                                    Environment.startRecording();
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "The desktop portal chooses a monitor or window. Audio and cursor capture are enabled by default."
                        wrapMode: Text.WordWrap
                        color: Theme.muted
                        font.family: Theme.fontText
                        font.pixelSize: 11
                        lineHeight: 1.25
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 11
                        color: recordingFolderPointer.containsMouse ? Theme.barNeutralHover : Theme.barNeutral
                        Text { anchors.centerIn: parent; text: "OPEN RECORDING ARCHIVE"; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                        MouseArea { id: recordingFolderPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Environment.openRecordingFolder() }
                    }
                }
            }
        }
    }
}
