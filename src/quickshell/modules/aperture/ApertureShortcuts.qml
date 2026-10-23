import QtQuick

// These actions belong to the containing editor/popover window. A sibling
// focus catcher cannot receive them once a button or switch takes keyboard focus.
Item {
    id: root

    property bool studioActions: false
    signal closeRequested()
    signal undoRequested()
    signal tabRequested(string tab)

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible
        onActivated: root.closeRequested()
    }
    Shortcut {
        sequence: "Ctrl+Z"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible && root.studioActions
        onActivated: root.undoRequested()
    }
    Shortcut {
        sequence: "1"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible && root.studioActions
        onActivated: root.tabRequested("colors")
    }
    Shortcut {
        sequence: "2"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible && root.studioActions
        onActivated: root.tabRequested("position")
    }
    Shortcut {
        sequence: "3"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible && root.studioActions
        onActivated: root.tabRequested("presets")
    }
    Shortcut {
        sequence: "4"
        context: Qt.WindowShortcut
        enabled: root.enabled && root.visible && root.studioActions
        onActivated: root.tabRequested("shelf")
    }
}
