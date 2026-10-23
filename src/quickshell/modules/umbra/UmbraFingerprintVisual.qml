import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "UmbraFingerprintState.js" as FingerprintState

// Presentation only. Authentication, cancellation and capability stay in Umbra.
Row {
    id: root
    property string look: Settings.umbraFingerprintLook
    property bool showText: Settings.umbraFingerprintShowText
    property bool interactive: false
    readonly property string authState: FingerprintState.state(Umbra.authenticating,Umbra.authMethod,Umbra.failed,Umbra.unlocking)
    readonly property string label: authState === "success" ? "Unlocked"
        : authState === "pending" ? "Waiting for reader…" : authState === "failed" ? "Retry fingerprint" : "Use fingerprint"
    readonly property color ink: authState === "failed" ? Theme.danger : authState === "success" ? Theme.cyan : Theme.accent
    spacing: 8
    Rectangle {
        width: 42; height: 42; radius: root.look === "orbital" ? 21 : Theme.radiusSmall
        color: Theme.controlRest; border.width: pointer.containsMouse || activeFocus ? 1 : 0; border.color: Theme.focusRing
        Accessible.role: Accessible.Button
        Accessible.name: root.label
        Accessible.onPressAction: if (pointer.enabled) Umbra.submitFingerprint()
        activeFocusOnTab: root.interactive
        Keys.onReturnPressed: if (pointer.enabled) Umbra.submitFingerprint()
        Keys.onSpacePressed: if (pointer.enabled) Umbra.submitFingerprint()
        Canvas {
            id: mark
            anchors.centerIn: parent; width: 32; height: 32
            onPaint: {
                const c=getContext("2d"); c.clearRect(0,0,width,height);
                c.strokeStyle=root.ink; c.lineWidth=1.5; c.lineCap="round";
                if (root.look === "orbital") {
                    for(let r=5;r<=13;r+=4) { c.beginPath(); c.arc(16,16,r,-Math.PI*.8,Math.PI*.6); c.stroke(); }
                    c.fillStyle=root.ink; c.beginPath(); c.arc(24,7,2,0,Math.PI*2); c.fill();
                } else {
                    for(let r=4;r<=13;r+=3) { c.beginPath(); c.arc(16,14,r,Math.PI,0); c.lineTo(16+r,21); c.stroke(); }
                    c.beginPath(); c.moveTo(16,13); c.bezierCurveTo(12,15,20,23,13,28); c.stroke();
                }
                if (root.authState === "success") { c.beginPath(); c.moveTo(9,17); c.lineTo(14,22); c.lineTo(24,10); c.stroke(); }
            }
            Connections {
                target: root
                function onLookChanged() { mark.requestPaint(); }
                function onInkChanged() { mark.requestPaint(); }
                function onAuthStateChanged() { mark.requestPaint(); }
            }
        }
        MouseArea {
            id: pointer
            anchors.fill: parent; hoverEnabled: true
            enabled: root.interactive && Umbra.fingerprintAvailable && !Umbra.authenticating && !Umbra.unlocking
            cursorShape: Qt.PointingHandCursor
            onClicked: Umbra.submitFingerprint()
        }
    }
    Text {
        visible: root.showText
        height: 42; verticalAlignment: Text.AlignVCenter
        text: root.label; color: root.ink; font.family: Theme.fontText; font.pixelSize: 12
    }
}
