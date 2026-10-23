import QtQuick
import QtQml.Models
import ".."

// A control finish only. Text and the owner's fixed input rectangle are untouched.
Rectangle {
    id: root
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool focused: false
    property color tint: Theme.accent
    property string material: backdrop ? backdrop.material : Settings.controlMaterial
    property var ancestry: []
    property var backdrop: null
    property rect sampleRect: Qt.rect(0, 0, 1, 1)
    property vector2d sampleOrigin: Qt.vector2d(0, 0)
    property vector2d sampleBasisX: Qt.vector2d(1, 0)
    property vector2d sampleBasisY: Qt.vector2d(0, 1)
    readonly property bool supported: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool shaderActive: !!shaderLoader.item && shaderLoader.item.status !== ShaderEffect.Error
    property real hoverLight: hovered ? 1 : 0
    property real pressLight: pressed ? 1 : 0
    Behavior on hoverLight { NumberAnimation { duration: Theme.motionNormal; easing.type: Easing.OutCubic } }
    Behavior on pressLight { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
    radius: Theme.radiusSmall
    visible: Settings.opticalControls
    opacity: enabled ? 1 : 0.35
    color: "transparent"
    border.width: 1
    border.color: focused ? Theme.focusRing : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b,
        pressed ? 0.04 : hovered || selected ? 0.14 : 0.055)
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, (root.pressed ? 0.015 : root.hovered ? 0.09 : 0.035) * Theme.controlFillOpacity) }
        GradientStop { position: 0.45; color: "transparent" }
        GradientStop { position: 1; color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, (root.selected ? 0.065 : 0.012) * Theme.controlFillOpacity) }
    }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

    function resolveBackdrop() {
        const chain = []; let item = root; let provider = null;
        while (item) {
            chain.push(item);
            if (item !== root && item.opticalBackdrop !== undefined && item.opticalBackdrop) {
                provider = item.opticalBackdrop;
                // Continue through the provider's parent for movement and scale.
                break;
            }
            item = item.parent;
        }
        ancestry = chain; backdrop = provider; updateMapping();
    }
    function updateMapping() {
        if (!backdrop || backdrop.width <= 0 || backdrop.height <= 0) return;
        const bounds = root.mapToItem(backdrop, 0, 0, width, height);
        const origin = root.mapToItem(backdrop, 0, 0);
        const endX = root.mapToItem(backdrop, width, 0);
        const endY = root.mapToItem(backdrop, 0, height);
        const viewportWidth = Math.max(1, backdrop.viewportSize.width);
        const viewportHeight = Math.max(1, backdrop.viewportSize.height);
        // Three points retain ancestor rotation and scale; an axis-aligned
        // bounding rectangle alone loses the wallpaper's orientation.
        sampleOrigin = Qt.vector2d((origin.x + backdrop.viewportOffset.x) / viewportWidth,
                                   (origin.y + backdrop.viewportOffset.y) / viewportHeight);
        sampleBasisX = Qt.vector2d((endX.x - origin.x) / viewportWidth, (endX.y - origin.y) / viewportHeight);
        sampleBasisY = Qt.vector2d((endY.x - origin.x) / viewportWidth, (endY.y - origin.y) / viewportHeight);
        sampleRect = Qt.rect((bounds.x + backdrop.viewportOffset.x) / Math.max(1, backdrop.viewportSize.width),
                             (bounds.y + backdrop.viewportOffset.y) / Math.max(1, backdrop.viewportSize.height),
                             bounds.width / Math.max(1, backdrop.viewportSize.width), bounds.height / Math.max(1, backdrop.viewportSize.height));
    }
    Component.onCompleted: resolveBackdrop()
    onParentChanged: resolveBackdrop()
    Instantiator {
        model: root.visible && root.material !== "etched" ? root.ancestry : []
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onXChanged() { root.updateMapping(); }
            function onYChanged() { root.updateMapping(); }
            function onWidthChanged() { root.updateMapping(); }
            function onHeightChanged() { root.updateMapping(); }
            function onScaleChanged() { root.updateMapping(); }
            function onRotationChanged() { root.updateMapping(); }
            function onContentXChanged() { root.updateMapping(); }
            function onContentYChanged() { root.updateMapping(); }
            function onParentChanged() { if (root) root.resolveBackdrop(); }
            function onOpticalBackdropChanged() { if (root) root.resolveBackdrop(); }
        }
    }
    Connections {
        target: root.backdrop
        function onWidthChanged() { root.updateMapping(); }
        function onHeightChanged() { root.updateMapping(); }
        function onViewportSizeChanged() { root.updateMapping(); }
        function onViewportOffsetChanged() { root.updateMapping(); }
        function onGeometryRevisionChanged() { root.updateMapping(); }
    }
    Loader {
        id: shaderLoader
        anchors.fill: parent
        onLoaded: root.updateMapping()
        active: root.visible && root.supported && root.material !== "etched" && !!root.backdrop && root.backdrop.ready
        sourceComponent: ShaderEffect {
            visible: status !== ShaderEffect.Error
            property var wallpaper: root.backdrop ? root.backdrop.texture : null
            property vector2d viewport: Qt.vector2d(width, height)
            property vector2d sampleOrigin: root.sampleOrigin
            property vector2d sampleBasisX: root.sampleBasisX
            property vector2d sampleBasisY: root.sampleBasisY
            property vector2d cropScale: root.backdrop ? root.backdrop.cropScale : Qt.vector2d(1, 1)
            property real cornerRadius: root.radius
            property real strength: Math.max(0, Math.min(1, Settings.opticalStrength))
            property real frost: root.material === "frosted" ? Math.max(.3, Settings.opticalFrost) : Settings.opticalFrost * .25
            property real dispersion: Math.max(0, Math.min(1, Settings.opticalDispersion))
            property real hoverLight: root.hoverLight
            property real pressLight: root.pressLight
            property real fillOpacity: Theme.controlFillOpacity
            property color tint: root.tint
            property color backing: Theme.void_
            fragmentShader: Qt.resolvedUrl("shaders/optical.frag.qsb")
        }
    }
}
