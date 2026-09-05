import QtQuick
import QtQuick.Effects
import "../.."

Item {
    id: root

    property url artSource: ""
    property bool playing: false
    property real phase: 0
    property real energy: 0

    implicitWidth: 112
    implicitHeight: 112

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.elevated
    }

    Image {
        id: art
        anchors.fill: parent
        source: root.artSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: circularMask
        anchors.fill: parent
        radius: width / 2
        color: "white"
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        maskEnabled: true
        maskSource: circularMask
        visible: root.artSource.toString().length > 0
        rotation: root.playing ? root.phase * 360 : 0
    }

    // A compact disc reads through its hub and changing specular surface, not
    // through an outline around the artwork.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        rotation: root.playing ? root.phase * 360 : 0
        opacity: 0.34 + root.energy * 0.18
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.28; color: Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.30) }
            GradientStop { position: 0.42; color: "transparent" }
            GradientStop { position: 0.70; color: Qt.rgba(Theme.rose.r, Theme.rose.g, Theme.rose.b, 0.24) }
            GradientStop { position: 0.86; color: "transparent" }
            GradientStop { position: 1.00; color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.20) }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.24
        height: width
        radius: width / 2
        color: Theme.void_

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.34
            height: width
            radius: width / 2
            color: Theme.moon
            opacity: 0.74
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.045
        height: width
        radius: width / 2
        color: Theme.void_
    }
}
