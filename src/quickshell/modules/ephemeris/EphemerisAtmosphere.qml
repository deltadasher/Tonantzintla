import QtQuick
import "../.."

Item {
    id: root

    property string module: "apps"
    property real presentation: 1
    readonly property color primary: Theme.moduleAccent(module)
    readonly property color secondary: Theme.moduleSecondary(module)
    readonly property real density: Settings.atmosphereStyle === "quiet" ? 0.62
        : Settings.atmosphereStyle === "cinematic" ? 1.42 : 1
    readonly property int starCount: Settings.atmosphereStyle === "quiet" ? 5
        : Settings.atmosphereStyle === "cinematic" ? 11 : 8
    readonly property bool live: Settings.motion && Settings.animateStars && visible

    clip: true
    opacity: Settings.animateStars ? Math.min(0.72, 0.48 * density) * presentation : 0
    visible: opacity > 0.001

    Rectangle {
        width: Math.min(parent.width * 0.72, 760)
        height: width
        radius: width / 2
        x: -width * 0.34
        y: parent.height * 0.20 - height * 0.48
        color: root.primary
        opacity: 0.035 * root.density
        Behavior on color { ColorAnimation { duration: 420 } }
    }

    Rectangle {
        width: Math.min(parent.width * 0.58, 620)
        height: width
        radius: width / 2
        x: parent.width - width * 0.62
        y: parent.height - height * 0.56
        color: root.secondary
        opacity: 0.026 * root.density
        Behavior on color { ColorAnimation { duration: 420 } }
    }

    Item {
        id: orbitField
        width: parent.width * 0.78
        height: parent.height * 0.70
        anchors.centerIn: parent

        Repeater {
            model: 14
            Rectangle {
                required property int index
                readonly property real angle: index * Math.PI * 2 / 14
                width: 5
                height: 1
                color: root.primary
                opacity: 0.22
                x: orbitField.width * 0.5 + Math.cos(angle) * orbitField.width * 0.42 - width / 2
                y: orbitField.height * 0.5 + Math.sin(angle) * orbitField.height * 0.24 - height / 2
                rotation: angle * 180 / Math.PI
            }
        }

        Item {
            id: tickRing
            anchors.fill: parent
            transformOrigin: Item.Center

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 48000
                loops: Animation.Infinite
                running: root.live
            }

            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    width: index % 3 === 0 ? 3 : 2
                    height: width
                    radius: width / 2
                    color: index % 2 === 0 ? root.primary : root.secondary
                    opacity: index % 3 === 0 ? 0.55 : 0.28
                    x: tickRing.width * 0.5
                        + Math.cos(index * Math.PI * 2 / 7) * tickRing.width * 0.42
                        - width / 2
                    y: tickRing.height * 0.5
                        + Math.sin(index * Math.PI * 2 / 7) * tickRing.height * 0.24
                        - height / 2
                }
            }
        }
    }

    Item {
        id: comet
        visible: Settings.atmosphereStyle === "cinematic"
        width: 110
        height: 6
        y: parent.height * 0.22
        opacity: 0.36

        SequentialAnimation on x {
            running: root.live && comet.visible
            loops: Animation.Infinite
            NumberAnimation {
                from: -comet.width
                to: root.width + 20
                duration: 18000
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 3200 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: root.primary }
            }
        }
    }

    Repeater {
        model: root.starCount
        Rectangle {
            required property int index
            x: ((index * 211 + 67) % Math.max(1, root.width - 12))
            y: 36 + ((index * 127 + 43) % Math.max(1, root.height - 72))
            width: index % 4 === 0 ? 3 : 2
            height: width
            radius: width / 2
            color: index % 3 === 0 ? root.primary : Theme.moon
            opacity: 0.16 + (index % 3) * 0.04
        }
    }
}
