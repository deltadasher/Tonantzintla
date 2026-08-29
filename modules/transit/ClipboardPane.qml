import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"

Item {
    id: root

    property string query: ""
    readonly property var filteredEntries: Clipboard.entries.filter(function(entry) {
        const needle = root.query.trim().toLowerCase();
        return needle.length === 0 || entry.search.indexOf(needle) >= 0;
    })

    function focusSearch() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
        Clipboard.refresh();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "CLIPBOARD"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }
            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: width / 2
                color: clearPointer.containsMouse ? Theme.danger : Theme.controlRest
                border.width: 0
                border.color: Theme.line
                Text {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "×"
                    color: clearPointer.containsMouse ? Theme.void_ : Theme.muted
                    font.family: Theme.fontDisplay
                    font.pixelSize: 18
                }
                MouseArea {
                    id: clearPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Clipboard.clear()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Theme.radiusMedium
            color: Theme.mantle
            border.width: 0
            border.color: searchInput.activeFocus ? Theme.accentLine : Theme.line
            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                text: root.query
                color: Theme.moon
                selectionColor: Theme.accent
                selectedTextColor: Theme.void_
                font.family: Theme.fontMono
                font.pixelSize: 11
                onTextChanged: root.query = text
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text.length === 0
                text: "Search clipboard history…"
                color: Theme.lineBright
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }

        GridView {
            id: clipGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: width / 3
            cellHeight: 126
            model: root.filteredEntries

            delegate: Rectangle {
                id: clipCard
                required property var modelData
                width: clipGrid.cellWidth - 8
                height: clipGrid.cellHeight - 8
                radius: Theme.radiusMedium
                color: clipPointer.containsMouse ? Theme.elevated : Theme.mantle
                border.width: 0
                border.color: clipPointer.containsMouse ? Theme.accentLine : Theme.line
                clip: true
                scale: clipPointer.containsMouse ? 0.985 : 1

                Image {
                    anchors.fill: parent
                    source: clipCard.modelData.type === "image" ? "file://" + clipCard.modelData.content : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: clipCard.modelData.type === "image"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: clipCard.modelData.type === "text"
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: clipCard.modelData.content
                        color: Theme.moon
                        font.family: Theme.fontText
                        font.pixelSize: 10
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 5
                    }
                }


                MouseArea {
                    id: clipPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Clipboard.copy(clipCard.modelData.id);
                        ShellState.closeEphemeris();
                    }
                }

                Behavior on scale { NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            Text {
                anchors.centerIn: parent
                visible: clipGrid.count === 0
                text: Clipboard.available ? "NO CLIPS YET" : "INSTALL CLIPHIST + WL-CLIPBOARD"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }
}
