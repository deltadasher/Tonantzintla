import QtQuick
import "../.."

Item {
    id: root
    property color primary: Theme.accent
    property color secondary: Theme.cyan
    property real energy: 0
    property real deployment: 1
    property bool failed: false
    property bool authenticating: false
    property bool collapseActive: false
    property real collapseProgress: 0
    property real shock: 0
    property bool motionActive: true
    property real elapsed: 0
    readonly property real phase: (elapsed / 26) % 1
    readonly property bool animated: motionActive && visible && Settings.motion && Settings.umbraMotion

    // Uniform updates only: no full-size Canvas uploads or per-frame allocations.
    Timer {
        interval: 33
        repeat: true
        running: root.animated
        onTriggered: root.elapsed += interval / 1000
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("shaders/accretion-fallback.png")
        visible: root.GraphicsInfo.api === GraphicsInfo.Software || plasma.status === ShaderEffect.Error
        fillMode: Image.PreserveAspectFit
        opacity: Math.min(1, root.deployment * 1.6)
    }

    ShaderEffect {
        id: plasma
        visible: root.GraphicsInfo.api !== GraphicsInfo.Software
        anchors.fill: parent
        property real time: root.elapsed
        property real opening: root.deployment
        property real energy: root.energy + (root.authenticating ? 0.35 : 0)
        property real collapse: root.collapseProgress
        property real shock: root.shock
        property color primary: root.failed ? Theme.danger : root.primary
        property color secondary: root.failed ? Theme.danger : root.secondary
        property color coreColor: Theme.void_
        fragmentShader: Qt.resolvedUrl("shaders/accretion.frag.qsb")
    }
}
