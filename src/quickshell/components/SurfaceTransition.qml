import QtQuick

// Displayed content is owned here. Only swap tabs at zero opacity, then wait
// for the loader. Repeated requests coalesce; close cancels every entrance.
Item {
    id: root
    property bool requestedVisible: false
    property string requestedTab: "apps"
    property bool motionEnabled: true
    property bool contentReady: false
    property bool mounted: false
    property string activeTab: "apps"
    property string phase: "closed"
    property real contentProgress: 0
    property real revealProgress: 0
    readonly property bool interactive: phase === "open" && requestedVisible
    signal deploying()
    signal settled()

    function stopAnimations() {
        frame.stop(); enter.stop(); leave.stop(); closing.stop(); reveal.stop();
    }
    function show() {
        stopAnimations();
        phase = "mapping";
        contentProgress = 0;
        if (!mounted) revealProgress = 0;
        mounted = true;
        activeTab = requestedTab;
        frame.restart();
    }
    function hide() {
        stopAnimations();
        if (!mounted) { phase = "closed"; return; }
        phase = "closing";
        closing.restart();
    }
    function requestSwitch() {
        if (!requestedVisible || !mounted || activeTab === requestedTab) return;
        enter.stop(); frame.stop();
        if (phase === "leaving") return;
        phase = "leaving";
        leave.restart();
    }
    function swap() {
        if (!requestedVisible) { hide(); return; }
        phase = "loading";
        activeTab = requestedTab;
        frame.restart();
    }
    function tryEnter() {
        if (!requestedVisible || !mounted) return;
        if (activeTab !== requestedTab) { swap(); return; }
        if (phase !== "mapping" && phase !== "loading") return;
        if (revealProgress < 1) reveal.restart();
        phase = "loading";
        if (!contentReady) return;
        phase = "entering";
        deploying();
        enter.restart();
    }

    onRequestedVisibleChanged: requestedVisible ? show() : hide()
    onRequestedTabChanged: requestSwitch()
    onContentReadyChanged: if (contentReady && (phase === "loading" || phase === "mapping")) frame.restart()
    Component.onCompleted: if (requestedVisible) show()

    Timer { id: frame; interval: 16; onTriggered: root.tryEnter() }
    NumberAnimation {
        id: reveal; target: root; property: "revealProgress"; to: 1
        duration: root.motionEnabled ? 240 : 90; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: enter
        NumberAnimation { target: root; property: "contentProgress"; to: 1; duration: root.motionEnabled ? 260 : 90; easing.type: Easing.OutCubic }
        ScriptAction { script: { root.phase = "open"; root.settled(); root.requestSwitch(); } }
    }
    SequentialAnimation {
        id: leave
        NumberAnimation { target: root; property: "contentProgress"; to: 0; duration: root.motionEnabled ? 130 : 80; easing.type: Easing.InCubic }
        ScriptAction { script: root.swap() }
    }
    SequentialAnimation {
        id: closing
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentProgress"; to: 0; duration: root.motionEnabled ? 130 : 90 }
            NumberAnimation { target: root; property: "revealProgress"; to: 0; duration: root.motionEnabled ? 180 : 90 }
        }
        ScriptAction { script: { root.mounted = false; root.phase = "closed"; } }
    }
}
