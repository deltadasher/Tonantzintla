import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Only validated helper outputs belong here. At rest there is one full texture;
// replacement briefly uses a small old-image proxy, never two full textures.
PanelWindow {
    id: root
    required property var modelData
    property string preparedPath: ""
    required property int preparedWidth
    required property int preparedHeight
    property string transitionPreview: ""
    property int transitionWidth: 0
    property int transitionHeight: 0
    property string transitionName: "fade"
    property int revealSerial: 0
    property int generation: 0
    property bool motionEnabled: Theme.motionEnabled
    property int transitionDuration: Theme.duration(650)
    readonly property int graphicsApi: contentItem.GraphicsInfo.api
    readonly property bool shaderFailed: field.item && field.item.status === ShaderEffect.Error
    readonly property bool transitioning: reveal.running
    readonly property int loadedImageCount: (full.active ? 1 : 0) + (proxy.active ? 1 : 0)
    readonly property var stableImage: full.item
    readonly property string stablePath: current ? current.path : ""
    property bool presented: false
    property int presentedGeneration: -1
    readonly property bool ready: phase === "stable" && full.item && full.item.status === Image.Ready
        && stablePath === preparedPath && presented && presentedGeneration === generation
    readonly property string stateLabel: failedPath === preparedPath && preparedPath.length ? (current ? "Native still failed to load · previous still retained" : "Native still failed to load · external background retained")
        : ready ? (shaderFailed ? "Native still ready · static shader fallback" : "Native still ready")
        : "Loading native still"
    signal sourcePresented(string outputName, int generation)
    signal sourceFailed(string outputName, int generation, string message)
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    color: everShown ? "#000000" : "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tonantzintla-wallpaper"
    mask: Region {}

    property bool initialized: false
    property bool everShown: false
    property string phase: "empty"
    property var current: null
    property var wanted: null
    property var restoring: null
    property string fullPath: ""
    property size fullSize: Qt.size(1, 1)
    property string proxyPath: ""
    property size proxySize: Qt.size(1, 1)
    property string failedPath: ""
    property real progress: 0
    readonly property var displayedImage: ["proxy-present", "loading-full", "restoring", "transition"].indexOf(phase) >= 0 && proxy.item ? proxy.item : full.item
    readonly property int effect: transitionName === "grow" ? 1
        : ["wipe", "swipe", "diagonal"].indexOf(transitionName) >= 0 ? 2
        : ["orbit", "any"].indexOf(transitionName) >= 0 ? 3 : 0

    function urlFor(path) {
        return path.indexOf("/") === 0 ? "file://" + path.split("/").map(encodeURIComponent).join("/") : path;
    }
    function exactSize(w, h, cap) { return Qt.size(Math.max(1, Math.min(cap, w)), Math.max(1, Math.min(cap, h))); }
    function scheduleRequest() { if (initialized) requestTimer.restart(); }
    function snapshot() {
        return {path: preparedPath, size: exactSize(preparedWidth, preparedHeight, 2560),
            proxy: transitionPreview, proxySize: exactSize(transitionWidth, transitionHeight, 512), generation: generation};
    }
    function finishReveal() {
        reveal.stop(); phase = fullPath.length ? "stable" : "empty";
        proxyPath = ""; progress = 0; presented = false;
        if (contentItem.Window.window) contentItem.Window.window.update();
    }
    function refuseReplacement(message) {
        phase = "stable"; proxyPath = ""; failedPath = wanted ? wanted.path : preparedPath;
        sourceFailed(modelData.name, wanted ? wanted.generation : generation, message);
    }
    function request() {
        if (!initialized) return;
        if (reveal.running) finishReveal();
        wanted = snapshot(); failedPath = "";
        if (!preparedPath.length) {
            fullPath = ""; proxyPath = ""; current = null; wanted = null;
            phase = "empty"; presented = false; return;
        }
        if (current && preparedPath === current.path && full.item && full.item.status === Image.Ready) {
            current = wanted; proxyPath = ""; phase = "stable"; presented = false;
            if (contentItem.Window.window) contentItem.Window.window.update();
            return;
        }
        presented = false;
        if (proxy.item && proxy.item.status === Image.Ready && phase !== "loading-proxy") {
            phase = "proxy-present"; fullPath = "";
        } else if (current && full.item && full.item.status === Image.Ready
                   && current.proxy) {
            phase = "loading-proxy"; proxySize = current.proxySize; proxyPath = current.proxy;
            proxyLoaded();
        } else if (current && full.item && full.item.status === Image.Ready) {
            refuseReplacement("Transition preview unavailable; previous wallpaper retained. Select Retry to prepare it again.");
        } else {
            phase = "loading-full"; fullSize = wanted.size; fullPath = wanted.path;
            fullLoaded();
        }
        if (contentItem.Window.window) contentItem.Window.window.update();
    }
    function proxyLoaded() {
        if (phase !== "loading-proxy" || !proxy.item) return;
        if (proxy.item.status === Image.Error) {
            refuseReplacement("Transition preview could not be decoded; previous wallpaper retained. Select Retry to prepare it again.");
        } else if (proxy.item.status === Image.Ready) {
            phase = "proxy-present"; fullPath = "";
        }
        if (contentItem.Window.window) contentItem.Window.window.update();
    }
    function fullLoaded() {
        if ((phase !== "loading-full" && phase !== "restoring") || !full.item) return;
        if (full.item.status === Image.Error) {
            const firstFailure = failedPath !== (wanted ? wanted.path : preparedPath);
            failedPath = wanted ? wanted.path : preparedPath;
            if (firstFailure) sourceFailed(modelData.name, wanted ? wanted.generation : generation,
                "The prepared native still could not be decoded. Select Retry to prepare it again.");
            if (phase === "loading-full" && current && current.path !== fullPath) {
                restoring = current; phase = "restoring"; fullSize = current.size; fullPath = current.path;
            }
            return;
        }
        if (full.item.status !== Image.Ready) return;
        if (phase === "restoring") { current = restoring; finishReveal(); return; }
        current = wanted; everShown = true;
        if (proxy.item && proxy.item.status === Image.Ready && motionEnabled && transitionDuration > 0
                && transitionName !== "none" && graphicsApi !== GraphicsInfo.Software) {
            phase = "transition"; progress = 0; reveal.start();
        } else finishReveal();
    }
    function crop(image) {
        if (!image || image.implicitHeight <= 0) return Qt.vector2d(1, 1);
        const sourceAspect = image.implicitWidth / image.implicitHeight;
        const outputAspect = width / Math.max(1, height);
        return sourceAspect > outputAspect ? Qt.vector2d(outputAspect / sourceAspect, 1)
                                         : Qt.vector2d(1, sourceAspect / outputAspect);
    }
    onPreparedPathChanged: scheduleRequest()
    onPreparedWidthChanged: scheduleRequest()
    onPreparedHeightChanged: scheduleRequest()
    onTransitionPreviewChanged: scheduleRequest()
    onRevealSerialChanged: scheduleRequest()
    onGenerationChanged: scheduleRequest()
    onMotionEnabledChanged: if (!motionEnabled && reveal.running) finishReveal()
    Component.onCompleted: { initialized = true; scheduleRequest(); }
    Timer { id: requestTimer; interval: 0; onTriggered: root.request() }
    Connections {
        target: root.contentItem.Window.window
        enabled: root.phase === "proxy-present" || !root.presented
        function onFrameSwapped() {
            if (root.phase === "proxy-present" && root.wanted) {
                root.phase = "loading-full"; root.fullSize = root.wanted.size; root.fullPath = root.wanted.path;
                root.fullLoaded();
            } else if (root.phase === "stable" && full.item && full.item.status === Image.Ready
                       && root.stablePath === root.preparedPath && !requestTimer.running) {
                root.presentedGeneration = root.generation; root.presented = true;
                root.sourcePresented(root.modelData.name, root.generation);
            }
        }
    }
    NumberAnimation { id: reveal; target: root; property: "progress"; from: 0; to: 1
        duration: Math.max(0, root.transitionDuration); easing.type: Easing.InOutCubic
        onFinished: root.finishReveal()
    }
    Loader {
        id: full; anchors.fill: parent; active: root.fullPath.length > 0
        visible: (root.graphicsApi === GraphicsInfo.Software || root.shaderFailed) && root.displayedImage === item
        onLoaded: root.fullLoaded()
        sourceComponent: Image {
            source: root.urlFor(root.fullPath); sourceSize: root.fullSize
            fillMode: root.graphicsApi === GraphicsInfo.Software || root.shaderFailed ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true; cache: true; smooth: true; mipmap: false
            onStatusChanged: root.fullLoaded()
        }
    }
    Loader {
        id: proxy; anchors.fill: parent; active: root.proxyPath.length > 0
        visible: (root.graphicsApi === GraphicsInfo.Software || root.shaderFailed) && root.displayedImage === item
        onLoaded: root.proxyLoaded()
        sourceComponent: Image {
            source: root.urlFor(root.proxyPath); sourceSize: root.proxySize
            fillMode: root.graphicsApi === GraphicsInfo.Software || root.shaderFailed ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true; cache: true; smooth: true; mipmap: false
            onStatusChanged: root.proxyLoaded()
        }
    }
    Loader {
        id: field; anchors.fill: parent
        active: root.graphicsApi !== GraphicsInfo.Software && !!root.displayedImage && root.displayedImage.status === Image.Ready
        visible: !root.shaderFailed
        sourceComponent: ShaderEffect {
            readonly property var oldImage: root.displayedImage
            readonly property var newImage: full.item && full.item.status === Image.Ready ? full.item : root.displayedImage
            readonly property vector2d oldCrop: root.crop(root.displayedImage)
            readonly property vector2d newCrop: root.crop(full.item || root.displayedImage)
            readonly property vector2d dimensions: Qt.vector2d(width, height)
            readonly property real amount: reveal.running ? root.progress : 0
            readonly property real mode: root.effect
            fragmentShader: Qt.resolvedUrl("shaders/native-wallpaper.frag.qsb")
        }
    }
}
