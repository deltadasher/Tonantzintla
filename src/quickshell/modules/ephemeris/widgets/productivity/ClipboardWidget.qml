import QtQuick
import "../../../transit"

Item {
    function focusPrimary() { clipboardPane.focusSearch(); }
    ClipboardPane { id: clipboardPane; anchors.fill: parent }
}
