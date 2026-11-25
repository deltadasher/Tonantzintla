import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#111116"
    property int stage: 0
    property real phase: 0.0

    FrameAnimation {
        running: true
        onTriggered: root.phase = (root.phase + frameTime) % 628.3185
    }

    // GPU GLSL Gravitational Astrolabe & Starfield Shader
    ShaderEffect {
        anchors.fill: parent
        property real uTime: root.phase
        property real uProgress: Math.min(1, Math.max(0.14, root.stage / 6))
        property vector2d uResolution: Qt.vector2d(width, height)
        property color uAccent: "#c4b5ff"
        fragmentShader: Qt.resolvedUrl("shaders/splash_horizon.frag.qsb")
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.stage >= 1 ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }

        // Canonical Wabi Sabi Black Hole logo centered dead-center inside the concentric astrolabe rings
        Image {
            id: brandMark
            width: Math.min(126, Kirigami.Units.gridUnit * 7)
            height: width
            x: Math.round((parent.width - width) * 0.5)
            y: Math.round(parent.height * 0.45 - height * 0.5)
            source: "images/wabi-sabi.svg"
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Clean hairline progress bar positioned strictly below the outer astrolabe ring
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.45 + 148)
            width: Kirigami.Units.gridUnit * 10
            height: 3
            radius: 1.5
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
    }
}
