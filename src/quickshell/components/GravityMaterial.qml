import QtQuick
import ".."

// Direct scene-graph draw: no ShaderEffectSource, layer texture, or animation clock.
// Uniforms change only with the existing, bounded surface transition.
Item {
    id: root
    required property var geometry
    property real reveal: 1
    property real activity: 0
    property color primary: Theme.accent
    property color secondary: Theme.cyan
    property color backing: Theme.void_
    readonly property bool supported: root.GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool usable: supported && effect.status !== ShaderEffect.Error
    readonly property real halo: 72
    x: geometry.x - halo
    y: geometry.y - halo
    width: Math.max(1, geometry.width + halo * 2)
    height: Math.max(1, geometry.height + halo * 2)
    visible: usable && reveal > 0.001
    ShaderEffect {
        id: effect
        anchors.fill: parent
        property vector2d viewport: Qt.vector2d(width, height)
        property vector2d panelSize: Qt.vector2d(root.geometry.width, root.geometry.height)
        property real cornerRadius: root.geometry.radius
        property real reveal: root.reveal
        property real activity: root.activity
        property color primary: root.primary
        property color secondary: root.secondary
        property color backing: root.backing
        fragmentShader: root.supported ? Qt.resolvedUrl("shaders/gravity.frag.qsb") : ""
        onStatusChanged: if (status === ShaderEffect.Error)
            console.warn("Gravity material unavailable; retaining classic panel backing:", log)
    }
}
