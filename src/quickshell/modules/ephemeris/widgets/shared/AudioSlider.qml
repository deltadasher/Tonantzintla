import QtQuick
import QtQuick.Layouts
import "../../../.."

Item {
    id: root

    property real value: 0
    property real maximumValue: 150
    property real stepSize: 2
    property bool muted: false
    property color accentColor: Theme.accent
    property real previewValue: value
    property bool interacting: false
    readonly property real ratio: Math.max(0, Math.min(1, previewValue / maximumValue))
    signal valueRequested(real value)

    implicitHeight: 42
    activeFocusOnTab: true

    function clamp(value) {
        return Math.max(0, Math.min(maximumValue, value));
    }

    function setFromPosition(position, commitNow) {
        previewValue = clamp(position / Math.max(1, track.width) * maximumValue);
        if (commitNow) {
            commitTimer.stop();
            valueRequested(Math.round(previewValue));
        } else {
            commitTimer.restart();
        }
    }

    function nudge(delta) {
        previewValue = clamp(previewValue + delta);
        valueRequested(Math.round(previewValue));
    }

    onValueChanged: {
        if (!interacting)
            previewValue = value;
    }

    Keys.onLeftPressed: function(event) { nudge(-stepSize); event.accepted = true; }
    Keys.onRightPressed: function(event) { nudge(stepSize); event.accepted = true; }
    Keys.onDownPressed: function(event) { nudge(-stepSize); event.accepted = true; }
    Keys.onUpPressed: function(event) { nudge(stepSize); event.accepted = true; }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        height: 9
        radius: 5
        color: Theme.line
        border.width: 0
        border.color: root.accentColor
        clip: false

        Repeater {
            model: [0, 25, 50, 75, 100, 125, 150]
            Rectangle {
                required property int modelData
                visible: modelData <= root.maximumValue
                x: track.width * modelData / root.maximumValue - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: modelData % 50 === 0 ? 2 : 1
                height: modelData % 50 === 0 ? 13 : 7
                radius: 1
                color: Theme.lineBright
                opacity: 0.65
            }
        }

        Rectangle {
            width: track.width * root.ratio
            height: parent.height
            radius: parent.radius
            color: root.muted ? Theme.lineBright : root.accentColor
            opacity: root.muted ? 0.45 : 1
            Behavior on width {
                enabled: !root.interacting
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            visible: root.maximumValue > 100
            x: track.width * 100 / root.maximumValue
            width: track.width - x
            height: parent.height
            radius: parent.radius
            color: Theme.warning
            opacity: root.previewValue > 100 ? 0.16 : 0.05
        }

        Rectangle {
            x: track.width * root.ratio - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.interacting || hover.hovered || root.activeFocus ? 21 : 17
            height: width
            radius: width / 2
            color: root.muted ? Theme.muted : Theme.moon
            border.width: 0
            border.color: root.muted ? Theme.lineBright : root.accentColor
            scale: root.interacting ? 1.12 : 1

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 3
                color: root.muted ? Theme.line : root.accentColor
            }

            Behavior on x {
                enabled: !root.interacting
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
        }
    }

    Rectangle {
        visible: hover.hovered || root.interacting || root.activeFocus
        x: Math.max(0, Math.min(root.width - width,
            track.x + track.width * root.ratio - width / 2))
        y: -9
        width: valueLabel.implicitWidth + 14
        height: 22
        radius: 8
        color: Theme.void_
        border.width: 0
        border.color: root.previewValue > 100 ? Theme.warning : root.accentColor
        z: 4
        Text {
            id: valueLabel
            anchors.centerIn: parent
            text: Math.round(root.previewValue) + "%"
            color: root.previewValue > 100 ? Theme.warning : Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) {
            root.forceActiveFocus();
            root.interacting = true;
            root.setFromPosition(mouse.x - track.x, false);
        }
        onPositionChanged: function(mouse) {
            if (pressed)
                root.setFromPosition(mouse.x - track.x, false);
        }
        onReleased: function(mouse) {
            root.setFromPosition(mouse.x - track.x, true);
            root.interacting = false;
        }
        onCanceled: {
            commitTimer.stop();
            root.interacting = false;
            root.previewValue = root.value;
        }
        onWheel: function(event) {
            root.nudge(event.angleDelta.y > 0 ? root.stepSize : -root.stepSize);
            event.accepted = true;
        }
    }

    Timer {
        id: commitTimer
        interval: 70
        onTriggered: root.valueRequested(Math.round(root.previewValue))
    }
}
