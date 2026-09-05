import QtQuick
import QtQuick.Layouts
import "../shared" as Shared
import "../../../.."
import "../../../../components"
import "../../../../services"

Item {
    id: root

    property string activeTab: "outputs"
    readonly property var activeNodes: activeTab === "outputs" ? Audio.outputs
        : activeTab === "inputs" ? Audio.inputs : Audio.apps
    readonly property color activeColor: activeTab === "outputs" ? Theme.cyan
        : activeTab === "inputs" ? Theme.rose : Theme.violet
    readonly property bool masterIsInput: activeTab === "inputs"
    readonly property real masterValue: masterIsInput ? Audio.inputPercent : Audio.percent
    readonly property bool masterMuted: masterIsInput ? Audio.inputMuted : Audio.muted
    readonly property string masterName: masterIsInput ? "MICROPHONE"
        : activeTab === "apps" ? "APP VOLUME" : Audio.defaultOutputName
    readonly property string masterDetail: masterIsInput
        ? "Default PipeWire input gain" : Audio.defaultOutputDetail

    ColumnLayout {
        anchors.fill: parent
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "AUDIO"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.DemiBold
            }
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 11
                color: refreshPointer.containsMouse ? Theme.accentVeil : Theme.mantle
                border.width: 0; border.color: refreshPointer.containsMouse ? Theme.accentLine : Theme.line
                Text { anchors.centerIn: parent; text: "↻"; color: Theme.accent; font.family: Theme.fontDisplay; font.pixelSize: 16 }
                MouseArea { id: refreshPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.refresh() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 166
            radius: Theme.radiusLarge
            color: Theme.mantle
            border.width: 0
            border.color: root.masterMuted ? Theme.warning : Theme.barHairlineHover
            clip: true

            Rectangle {
                width: parent.width * 0.58
                height: width
                radius: width / 2
                x: -width * 0.22
                y: -height * 0.50
                color: root.activeColor
                opacity: 0.035
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 18
                spacing: 18

                AudioOrb {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 130
                    value: masterSlider.interacting ? masterSlider.previewValue : root.masterValue
                    muted: root.masterMuted
                    accentColor: root.activeColor
                    label: root.masterIsInput ? "INPUT" : "OUTPUT"
                    energized: masterSlider.interacting
                    onActivated: {
                        if (root.masterIsInput) Audio.toggleMicrophone();
                        else Audio.toggleMute();
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.masterName
                            color: Theme.moon
                            font.family: Theme.fontDisplay
                            font.pixelSize: 16
                            font.weight: Font.Black
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.masterDetail
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.masterIsInput ? "MIC LEVEL" : "VOLUME"
                            color: root.activeColor
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                        Text {
                            text: root.masterMuted ? "MUTED" : root.masterValue + "%"
                            color: root.masterMuted ? Theme.warning : Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }

                    Shared.AudioSlider {
                        id: masterSlider
                        Layout.fillWidth: true
                        value: root.masterValue
                        muted: root.masterMuted
                        accentColor: root.activeColor
                        onValueRequested: function(nextValue) {
                            if (root.masterIsInput)
                                Audio.setMicrophoneVolume(nextValue);
                            else
                                Audio.setVolume(nextValue);
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: muteLabel.implicitWidth + 24
                        Layout.preferredHeight: 30
                        radius: 9
                        color: mutePointer.containsMouse ? Theme.barNeutralHover : Theme.barNeutral
                        Text {
                            id: muteLabel
                            anchors.centerIn: parent
                            text: root.masterMuted ? "UNMUTE" : "MUTE"
                            color: root.masterMuted ? Theme.success : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: mutePointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.masterIsInput) Audio.toggleMicrophone();
                                else Audio.toggleMute();
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Repeater {
                model: [
                    { "id": "outputs", "label": "OUTPUTS", "count": Audio.outputs.length },
                    { "id": "inputs", "label": "INPUTS", "count": Audio.inputs.length },
                    { "id": "apps", "label": "APPLICATIONS", "count": Audio.apps.length }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 11
                    readonly property bool selected: root.activeTab === modelData.id
                    color: selected ? Theme.accentVeil : tabPointer.containsMouse ? Theme.elevated : Theme.mantle
                    border.width: 0; border.color: selected ? Theme.accentLine : Theme.line
                    RowLayout {
                        anchors.centerIn: parent; spacing: 7
                        Text { text: modelData.label; color: parent.parent.selected ? Theme.accent : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.7 }
                        Rectangle { implicitWidth: 20; implicitHeight: 18; radius: 7; color: Theme.elevated; Text { anchors.centerIn: parent; text: modelData.count; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 10 } }
                    }
                    MouseArea { id: tabPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activeTab = modelData.id }
                }
            }
        }

        ListView {
            id: nodeList
            Layout.fillWidth: true; Layout.fillHeight: true
            model: root.activeNodes
            spacing: 8; clip: true

            SpectrumField {
                anchors.fill: parent
                anchors.margins: 8
                visible: nodeList.count === 0
                accentColor: root.activeColor
                secondaryColor: root.activeTab === "inputs" ? Theme.violet : Theme.cyan
                title: root.activeTab === "apps"
                    ? "NO APPLICATION STREAMS PLAYING"
                    : Audio.mixerAvailable ? "NO AUDIO NODES DETECTED"
                    : "PIPEWIRE LINK OFFLINE"
                detail: Spectrum.available
                    ? "VISUALIZER ACTIVE"
                    : "NO AUDIO PLAYING"
            }

            delegate: Rectangle {
                id: nodeCard
                required property var modelData
                readonly property bool isDefault: Audio.isDefaultNode(modelData)
                readonly property int volumePercent: Audio.nodePercent(modelData)
                readonly property bool muted: Audio.nodeMuted(modelData)
                width: nodeList.width; height: 116; radius: Theme.radiusMedium
                color: isDefault
                    ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.20)
                    : nodePointer.containsMouse ? Theme.controlHover : Theme.controlRest
                border.width: 0

                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 11
                    Rectangle {
                        Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 14
                        color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.13)
                        Text { anchors.centerIn: parent; text: root.activeTab === "outputs" ? "♪" : root.activeTab === "inputs" ? "●" : "▶"; color: root.activeColor; font.family: Theme.fontDisplay; font.pixelSize: 15; font.weight: Font.Bold }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; text: Audio.nodeTitle(nodeCard.modelData); color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: Audio.nodeSubtitle(nodeCard.modelData); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                            Text { text: nodeCard.muted ? "MUTED" : nodeCard.volumePercent + "%"; color: nodeCard.muted ? Theme.warning : Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                        }
                        Shared.AudioSlider {
                            Layout.fillWidth: true
                            value: nodeCard.volumePercent
                            muted: nodeCard.muted
                            accentColor: root.activeColor
                            onValueRequested: function(nextValue) {
                                Audio.setNodeVolume(nodeCard.modelData, nextValue);
                            }
                        }
                    }
                    ColumnLayout {
                        spacing: 5
                        Rectangle {
                            visible: root.activeTab !== "apps"
                            Layout.preferredWidth: 72; Layout.preferredHeight: 28; radius: 9
                            color: nodeCard.isDefault ? Theme.accentVeil : defaultPointer.containsMouse ? Theme.elevated : Theme.mantle
                            border.width: 0; border.color: nodeCard.isDefault ? Theme.accentLine : Theme.line
                            Text { anchors.centerIn: parent; text: nodeCard.isDefault ? "DEFAULT" : "MAKE DEFAULT"; color: nodeCard.isDefault ? Theme.accent : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            MouseArea { id: defaultPointer; anchors.fill: parent; enabled: !nodeCard.isDefault; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.setDefaultNode(nodeCard.modelData) }
                        }
                        Rectangle {
                            Layout.preferredWidth: 72; Layout.preferredHeight: 28; radius: 9
                            color: nodeMutePointer.containsMouse ? Theme.elevated : Theme.mantle
                            border.width: 0; border.color: nodeCard.muted ? Theme.warning : Theme.line
                            Text { anchors.centerIn: parent; text: nodeCard.muted ? "UNMUTE" : "MUTE"; color: nodeCard.muted ? Theme.warning : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                            MouseArea { id: nodeMutePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleNodeMute(nodeCard.modelData) }
                        }
                    }
                }
                HoverHandler { id: nodePointer }
            }

        }
    }
}
