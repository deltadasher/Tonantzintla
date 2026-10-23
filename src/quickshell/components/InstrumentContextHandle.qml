import QtQuick

// The open instrument is its own preview. Keep the entry outside its content;
// short viewports retain the window shortcut and the existing modifier gesture.
ActionButton {
    id: root
    property rect panelBounds: Qt.rect(0, 0, 0, 0)
    property size viewportSize: Qt.size(0, 0)
    property bool active: true
    signal customizationRequested()
    readonly property bool roomAbove: panelBounds.y >= height + 6
    readonly property bool roomBelow: panelBounds.y + panelBounds.height + height + 6 <= viewportSize.height

    width: Math.max(0, Math.min(148, viewportSize.width))
    height: 28
    x: Math.max(0, Math.min(viewportSize.width - width, panelBounds.x + panelBounds.width - width))
    y: roomAbove ? panelBounds.y - height - 6 : panelBounds.y + panelBounds.height + 6
    visible: active && (roomAbove || roomBelow)
    text: "Customize · F10"
    Accessible.name: "Customize this instrument"
    Accessible.description: "F10 or Super+Alt+click opens the same instrument settings."
    onClicked: customizationRequested()

    Shortcut {
        sequence: "F10"
        context: Qt.WindowShortcut
        enabled: root.active && root.enabled
        onActivated: root.customizationRequested()
    }
}
