import QtQuick 2.15

Item {
    id: root

    property string symbol: "•"
    property string label: ""
    property color accent: "#a99cff"
    property color foreground: "#eee9dc"
    property color surface: "#171a28"
    property bool selected: false
    property bool enabled: true
    signal triggered()

    implicitWidth: 54
    implicitHeight: 54
    opacity: enabled ? 1 : 0.28
    scale: pointer.pressed ? 0.90 : pointer.containsMouse ? 1.08 : 1

    Behavior on scale {
        NumberAnimation { duration: 170; easing.type: Easing.OutBack }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.selected || pointer.containsMouse
            ? root.accent
            : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.symbol
        color: root.selected || pointer.containsMouse ? "#080910" : root.accent
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(parent.width * 0.34)
        font.weight: Font.Bold
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 8
        text: root.label.toUpperCase()
        visible: pointer.containsMouse && root.label.length > 0
        color: root.foreground
        font.family: "JetBrains Mono"
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        opacity: pointer.containsMouse ? 0.78 : 0

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
