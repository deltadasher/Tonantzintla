pragma Singleton

import QtQuick
import ".."

QtObject {
    id: root

    property bool visible: false
    property string kind: "volume"
    property string label: "VOLUME"
    property int value: 0
    property bool muted: false
    property int serial: 0
    readonly property bool statusMode: ["capslock","numlock","airplane"].indexOf(kind)>=0
    readonly property bool enabledForKind: enabled(kind)
    readonly property int duration: Math.max(500, Math.min(5000, Settings.osdDuration))

    function enabled(nextKind) {
        return nextKind === "volume" ? Settings.osdVolume
            : nextKind === "microphone" ? Settings.osdMicrophone
            : nextKind === "brightness" ? Settings.osdBrightness
            : nextKind === "capslock" ? Settings.osdCapsLock
            : nextKind === "numlock" ? Settings.osdNumLock
            : nextKind === "airplane" ? Settings.osdAirplane : true;
    }
    onEnabledForKindChanged: if (!enabledForKind) { visible = false; hideTimer.stop(); }

    function show(nextKind, nextValue, nextLabel, nextMuted) {
        if (!enabled(nextKind || "volume") || !isFinite(nextValue)) return;
        kind = nextKind || "volume";
        value = Math.max(0, Math.min(150, Math.round(nextValue)));
        label = nextLabel || kind.toUpperCase();
        muted = nextMuted === true;
        visible = true;
        serial++;
        hideTimer.restart();
    }

    function showStatus(nextKind, active) {
        if(["capslock","numlock","airplane"].indexOf(nextKind)<0 || typeof active!=="boolean") return false;
        const labels={capslock:"Caps Lock",numlock:"Num Lock",airplane:"Airplane mode"};
        show(nextKind,active?100:0,labels[nextKind],false);
        return enabled(nextKind);
    }
    function previewStatus(nextKind) {
        if(showStatus(nextKind,true)) label="Preview · "+label;
    }

    property Timer hideTimer: Timer {
        interval: root.duration
        onTriggered: root.visible = false
    }
}
