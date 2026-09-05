import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"

Item {
    id: root

    property string query: ""
    property var hoveredEntry: null
    readonly property var currentEntry: hoveredEntry
        || (Clipboard.entries.length > 0 ? Clipboard.entries[0] : null)

    function focusSearch() {
        searchInput.forceActiveFocus();
        searchInput.cursorPosition = searchInput.text.length;
        Clipboard.refresh();
    }

    function clipKind(entry) {
        if (!entry)
            return "text";
        if (entry.type === "image")
            return "image";
        const content = String(entry.content || "").trim();
        if (/^(https?|ftp):\/\//i.test(content))
            return "url";
        if (content.indexOf("\n") >= 0 && /[{}()[\];]|=>|\b(function|class|const|let|def|fn)\b/.test(content))
            return "code";
        return "text";
    }

    function kindTone(kind) {
        return kind === "image" ? Theme.rose
            : kind === "url" ? Theme.cyan
            : kind === "code" ? Theme.violet : Theme.accent;
    }

    function contentLength(entry) {
        return entry && entry.type === "image" ? 1800
            : entry && Number(entry.size) > 0 ? Number(entry.size)
            : String(entry ? entry.content || "" : "").length;
    }

    function layerHeight(entry) {
        return Math.max(5, Math.min(24,
            4 + Math.sqrt(Math.min(1800, contentLength(entry))) * 0.46));
    }

    function matches(entry) {
        const needle = query.trim().toLowerCase();
        return needle.length === 0 || String(entry.search || "").indexOf(needle) >= 0;
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
            Text {
                text: Clipboard.entries.length + (Clipboard.entries.length === 1 ? " CLIP" : " CLIPS")
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
            }
            Rectangle {
                implicitWidth: 70
                implicitHeight: 34
                radius: 11
                color: clearPointer.containsMouse ? Theme.danger : Theme.controlRest
                Text {
                    anchors.centerIn: parent
                    text: "CLEAR"
                    color: clearPointer.containsMouse ? Theme.void_ : Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
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
                text: "Search; non-matching layers collapse…"
                color: Theme.lineBright
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 178
                Layout.fillHeight: true
                radius: 24
                color: Qt.rgba(Theme.elevated.r, Theme.elevated.g, Theme.elevated.b, 0.58)
                clip: true

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    text: "NOW"
                    color: Theme.moon
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 1.4
                    z: 3
                }
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    text: "OLDER"
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 1.4
                    z: 3
                }

                ListView {
                    id: sediment
                    anchors.fill: parent
                    anchors.topMargin: 32
                    anchors.bottomMargin: 32
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 1
                    clip: true
                    model: Clipboard.entries
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: layer
                        required property int index
                        required property var modelData
                        readonly property bool match: root.matches(modelData)
                        readonly property string kind: root.clipKind(modelData)
                        width: sediment.width
                        height: match ? root.layerHeight(modelData) : 2
                        opacity: match ? Math.max(0.28,
                            1 - index / Math.max(1, Clipboard.entries.length) * 0.70) : 0.10
                        clip: true

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8 - (layer.index % 4) * 3
                            height: parent.height
                            radius: Math.min(3, height / 2)
                            color: root.kindTone(layer.kind)
                            opacity: layerPointer.containsMouse ? 1 : 0.72
                            scale: layerPointer.containsMouse ? 1.035 : 1
                            Behavior on scale {
                                NumberAnimation { duration: Settings.motion ? 140 : 0 }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: Settings.motion ? 120 : 0 }
                            }
                        }

                        MouseArea {
                            id: layerPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: layer.match
                            onEntered: root.hoveredEntry = layer.modelData
                            onExited: if (root.hoveredEntry === layer.modelData) root.hoveredEntry = null
                            onClicked: {
                                Clipboard.copy(layer.modelData.id);
                                ShellState.closeEphemeris();
                            }
                        }

                        Behavior on height { NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.InOutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Settings.motion ? 200 : 0 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: sediment.count === 0
                        text: Clipboard.available ? "NO CLIPS YET" : "INSTALL CLIPHIST + WL-CLIPBOARD"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 24
                color: Theme.mantle
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 16
                    source: root.currentEntry && root.currentEntry.type === "image"
                        ? "file://" + root.currentEntry.content : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: root.currentEntry && root.currentEntry.type === "image"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12
                    visible: !root.currentEntry || root.currentEntry.type !== "image"

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: root.currentEntry ? root.clipKind(root.currentEntry).toUpperCase() : "EMPTY"
                            color: root.currentEntry ? root.kindTone(root.clipKind(root.currentEntry)) : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Black
                        }
                        Text {
                            text: root.currentEntry ? root.contentLength(root.currentEntry) + " CHARS" : ""
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.currentEntry ? root.currentEntry.content : "Hover a layer to inspect it. Click to restore it."
                        color: root.currentEntry ? Theme.moon : Theme.muted
                        font.family: root.currentEntry && root.clipKind(root.currentEntry) === "code"
                            ? Theme.fontMono : Theme.fontText
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 22
                    }
                }

                Rectangle {
                    visible: root.currentEntry !== null
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    width: 116
                    height: 38
                    radius: 12
                    color: copyPointer.containsMouse ? Theme.cyan : Theme.accent
                    Text { anchors.centerIn: parent; text: "RESTORE CLIP"; color: Theme.void_; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Black }
                    MouseArea {
                        id: copyPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Clipboard.copy(root.currentEntry.id);
                            ShellState.closeEphemeris();
                        }
                    }
                }
            }
        }
    }
}
