import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../services"

Rectangle {
    id: root

    property int uid: 0
    property string appName: "System"
    property string summary: "Notification"
    property string body: ""
    property string icon: ""
    property string time: ""
    property bool critical: false
    property bool popup: false
    property double receivedAt: Date.now()
    property int urgency: 1
    property int count: 1
    property var actions: []
    readonly property real ageMs: Math.max(0, Notifications.now - receivedAt)
    readonly property real halfLifeMs: urgency <= 0 ? 12 * 60000 : 42 * 60000
    readonly property real freshness: critical ? 1 : Math.pow(0.5, ageMs / halfLifeMs)
    readonly property real visibleFreshness: popup ? 1 : freshness
    readonly property real massBoost: Math.min(28,
        Math.log(Math.max(1, count)) / Math.log(2) * 6)
    readonly property string iconSource: {
        const value = String(icon || "");
        if (!value.length)
            return "";
        if (value.indexOf("://") >= 0 || value.indexOf("image:") === 0)
            return value;
        if (value.charAt(0) === "/")
            return "file://" + value;
        return Quickshell.iconPath(value, true);
    }
    property int revealedSummary: popup ? 0 : summary.length
    property int revealedBody: popup ? 0 : body.length
    signal activated()
    signal dismissed()
    signal expired()
    signal actionInvoked(string identifier)

    implicitHeight: Math.max(78 + root.massBoost, content.implicitHeight + 20)
        * (root.critical ? 1 : 0.76 + root.visibleFreshness * 0.24)
    radius: Theme.radiusLarge
    color: critical ? Theme.controlDanger
        : hover.hovered ? Theme.controlHover : Theme.mantle
    opacity: hover.hovered || critical ? 1 : 0.42 + visibleFreshness * 0.58
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3 + root.visibleFreshness * 5
        color: root.critical ? Theme.void_ : Theme.accent
        opacity: 0.42 + root.visibleFreshness * 0.48
    }

    HoverHandler { id: hover }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.activated()
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.popup ? -2 : 0
        anchors.leftMargin: 12
        anchors.rightMargin: 76
        spacing: 11

        Rectangle {
            Layout.preferredWidth: 38 + Math.min(12, root.massBoost * 0.5)
            Layout.preferredHeight: Layout.preferredWidth
            radius: 12
            color: root.critical ? Qt.rgba(Theme.void_.r, Theme.void_.g,
                Theme.void_.b, 0.14) : Theme.accentVeil
            clip: true

            IconImage {
                id: iconImage
                anchors.fill: parent
                anchors.margins: 5
                source: root.iconSource
                asynchronous: true
                visible: root.iconSource.length > 0 && status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: !iconImage.visible
                text: root.appName.length > 0 ? root.appName.charAt(0).toUpperCase() : "•"
                color: root.critical ? Theme.void_ : Theme.accent
                font.family: Theme.fontDisplay
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Rectangle {
                visible: root.count > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 22
                height: 22
                radius: 11
                color: root.critical ? Theme.danger : Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: root.count > 99 ? "99+" : root.count
                    color: Theme.void_
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Black
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: root.appName.toUpperCase()
                        + (root.count > 1 ? "  ×" + root.count : "")
                    color: root.critical ? Theme.void_ : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.9
                    elide: Text.ElideRight
                }
                Text {
                    text: root.time
                    color: root.critical ? Theme.void_ : Theme.lineBright
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.summary.substring(0, root.revealedSummary)
                color: root.critical ? Theme.void_ : Theme.moon
                font.family: Theme.fontText
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body.substring(0, root.revealedBody)
                textFormat: Text.PlainText
                color: root.critical ? Qt.rgba(Theme.void_.r, Theme.void_.g,
                    Theme.void_.b, 0.76) : Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 11
                maximumLineCount: root.popup ? 2 : 3
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.actions && root.actions.length > 0

                Repeater {
                    model: root.actions || []
                    Rectangle {
                        required property var modelData
                        implicitWidth: actionLabel.implicitWidth + 18
                        implicitHeight: 25
                        radius: 8
                        color: actionPointer.containsMouse ? Theme.accent : Theme.controlRest
                        border.width: 0
                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: (modelData.text || modelData.identifier || "OPEN").toUpperCase()
                            color: actionPointer.containsMouse ? Theme.void_ : Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.7
                        }
                        MouseArea {
                            id: actionPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.actionInvoked(modelData.identifier)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

    }

    Rectangle {
        z: 2
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 70
        color: closePointer.containsMouse
            ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.11)
            : "transparent"

        Text {
            anchors.centerIn: parent
            text: "DISMISS"
            color: root.critical ? Theme.void_
                : closePointer.containsMouse ? Theme.danger : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Bold
        }

        MouseArea {
            id: closePointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissed()
        }
    }

    Rectangle {
        visible: root.popup
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 8
        height: 3
        radius: 2
        color: Theme.line
        clip: true

        Rectangle {
            width: Math.max(0, parent.width * (1 - timeout.progress))
            height: parent.height
            radius: parent.radius
            color: root.critical ? Theme.danger : Theme.accent
        }
    }

    Timer {
        id: timeout
        property real progress: 0
        interval: 50
        repeat: true
        running: root.popup && !hover.hovered
        onTriggered: {
            progress = Math.min(1, progress + interval / (root.critical ? 10000 : 6500));
            if (progress >= 1) {
                stop();
                root.expired();
            }
        }
    }

    SequentialAnimation {
        id: typewriter
        running: root.popup && Settings.motion
        NumberAnimation {
            target: root
            property: "revealedSummary"
            from: 0
            to: root.summary.length
            duration: Math.min(520, 70 + root.summary.length * 15)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 70 }
        NumberAnimation {
            target: root
            property: "revealedBody"
            from: 0
            to: root.body.length
            duration: Math.min(900, 60 + root.body.length * 10)
            easing.type: Easing.Linear
        }
    }

    Component.onCompleted: {
        if (!root.popup || !Settings.motion) {
            root.revealedSummary = root.summary.length;
            root.revealedBody = root.body.length;
        }
    }

    onSummaryChanged: {
        if (!popup || !Settings.motion)
            revealedSummary = summary.length;
    }
    onBodyChanged: {
        if (!popup || !Settings.motion)
            revealedBody = body.length;
    }
    onReceivedAtChanged: {
        if (!popup)
            return;
        timeout.progress = 0;
        timeout.restart();
        if (Settings.motion) {
            revealedSummary = 0;
            revealedBody = 0;
            typewriter.restart();
        } else {
            revealedSummary = summary.length;
            revealedBody = body.length;
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on implicitHeight {
        NumberAnimation { duration: Settings.motion ? 420 : 0; easing.type: Easing.OutCubic }
    }
    Behavior on opacity { NumberAnimation { duration: Settings.motion ? 300 : 0 } }
}
