import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

pragma ComponentBehavior: Bound

Item {

    onVisibleChanged: {
        if (visible)
            Notifications.markRead();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "NOTIFICATIONS"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 22
                font.weight: Font.DemiBold
            }

            Rectangle {
                implicitWidth: dndRow.implicitWidth + 18
                implicitHeight: 32
                radius: 16
                color: Settings.doNotDisturb ? Theme.accentVeil : Theme.mantle
                border.width: 0
                border.color: Settings.doNotDisturb ? Theme.accentLine : Theme.line
                RowLayout {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Settings.doNotDisturb ? Theme.warning : Theme.success
                    }
                    Text {
                        text: Settings.doNotDisturb ? "DND ACTIVE" : "NOTIFICATIONS ON"
                        color: Settings.doNotDisturb ? Theme.warning : Theme.moon
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.doNotDisturb = !Settings.doNotDisturb
                }
            }

            Rectangle {
                implicitWidth: 70
                implicitHeight: 32
                radius: 16
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
                    onClicked: Notifications.clearHistory()
                }
            }
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: Notifications.history

            delegate: NotificationCard {
                required property var model
                uid: model.uid
                appName: model.appName
                summary: model.summary
                body: model.body
                icon: model.icon
                time: model.time
                critical: model.critical
                receivedAt: model.receivedAt
                urgency: model.urgency
                count: model.count
                actions: model.actions || []
                width: historyList.width
                onActivated: Notifications.invokeDefault(uid)
                onActionInvoked: function(identifier) { Notifications.invokeAction(uid, identifier); }
                onDismissed: Notifications.removeHistory(uid)
            }

            Text {
                anchors.centerIn: parent
                visible: historyList.count === 0
                text: Settings.doNotDisturb ? "NO SOUND" : "NO NOTIFICATIONS"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.letterSpacing: 1
            }
        }
    }
}
