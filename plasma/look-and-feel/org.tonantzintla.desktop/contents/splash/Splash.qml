import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#111116"
    property int stage: 0

    Item {
        id: content
        anchors.fill: parent
        opacity: root.stage >= 1 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing * 2

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Kirigami.Units.gridUnit * 7
                height: width
                source: "images/wabi-sabi.svg"
                sourceSize: Qt.size(width, height)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Kirigami.Units.gridUnit * 10
                height: 4
                radius: 2
                color: "#20202a"
                clip: true

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: "#c4b5ff"
                    width: parent.width * Math.min(1, Math.max(0.14, root.stage / 6))
                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tonantzintla"
                color: "#eceaf2"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                font.letterSpacing: 1.5
            }
        }
    }
}
