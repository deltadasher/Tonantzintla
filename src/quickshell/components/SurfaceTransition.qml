import QtQuick

// Displayed content is owned here. Only swap tabs at zero opacity, then wait
// for the loader. Repeated requests coalesce; close cancels every entrance.
Item {
    id: root
    property bool requestedVisible: false
    property string requestedTab: "apps"
    property bool motionEnabled: true
    property int enterDuration: 280
    property int exitDuration: 190
    property int effectDuration: 140
    property real durationScale: 1
    readonly property bool animate: motionEnabled && durationScale > 0
    property bool contentReady: false
    property bool mounted: false
    property string activeTab: "apps"
    property string phase: "closed"
    property real contentProgress: 0
    property real revealProgress: 0
    readonly property bool interactive: phase === "open" && requestedVisible
    signal deploying()
    signal settled()

    function duration(milliseconds) {
        return animate ? Math.max(0, Math.round(milliseconds * durationScale)) : 0;
    }
    function settleWithoutMotion() {
        // Finish the active phase, including its completion action. Loader and
        // mapping waits remain intact, even when motion is disabled mid-flight.
        if (closing.running) closing.complete();
        else if (leave.running) leave.complete();
        else if (enter.running) enter.complete();
        if (reveal.running) reveal.complete();
    }
    function stopAnimations() {
        frame.stop(); enter.stop(); leave.stop(); closing.stop(); reveal.stop();
    }
    function show() {
        stopAnimations();
        // Reverse a close of the same mounted instrument from its current
        // frame. A different source must still swap only at zero opacity.
        const reversing = mounted && activeTab === requestedTab;
        phase = "mapping";
        if (!reversing) contentProgress = 0;
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

    onAnimateChanged: if (!animate) settleWithoutMotion()
    onRequestedVisibleChanged: requestedVisible ? show() : hide()
    onRequestedTabChanged: requestSwitch()
    onContentReadyChanged: if (contentReady && (phase === "loading" || phase === "mapping")) frame.restart()
    Component.onCompleted: if (requestedVisible) show()

    Timer { id: frame; interval: 16; onTriggered: root.tryEnter() }
    NumberAnimation {
        id: reveal; target: root; property: "revealProgress"; to: 1
        duration: root.duration(root.enterDuration); easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: enter
        NumberAnimation { target: root; property: "contentProgress"; to: 1; duration: root.duration(root.enterDuration); easing.type: Easing.OutCubic }
        ScriptAction { script: { root.phase = "open"; root.settled(); root.requestSwitch(); } }
    }
    SequentialAnimation {
        id: leave
        NumberAnimation { target: root; property: "contentProgress"; to: 0; duration: root.duration(root.effectDuration); easing.type: Easing.InCubic }
        ScriptAction { script: root.swap() }
    }
    SequentialAnimation {
        id: closing
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentProgress"; to: 0; duration: root.duration(root.effectDuration) }
            NumberAnimation { target: root; property: "revealProgress"; to: 0; duration: root.duration(root.exitDuration) }
        }
        ScriptAction { script: { root.mounted = false; root.phase = "closed"; } }
    }
}
