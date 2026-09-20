import QtQuick
import "../.."

Item {
    function focusPrimary() { pane.focusPrimary(); }
    SettingsPane { id: pane; anchors.fill: parent }
}
