import QtQuick
import "../../../transit"

Item {
    readonly property real preferredSurfaceHeight: clipboardPane.preferredSurfaceHeight
    function focusPrimary() { clipboardPane.focusSearch(); }
    ClipboardPane { id: clipboardPane; anchors.fill: parent }
}
