import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import "../../src/quickshell/modules/aperture"

TestCase {
    id: test
    name: "ApertureShortcuts"
    when: windowShown
    visible: true
    width: 360
    height: 180

    // Real window-scoped shortcut component, with focus owned by siblings as
    // it is when StudioControl or IslandSettingSwitch receives Tab focus.
    ApertureShortcuts { id: shortcuts }
    Column {
        Button { id: first; text: "First control" }
        Switch { id: second; text: "Quick setting" }
    }
    SignalSpy { id: closed; target: shortcuts; signalName: "closeRequested" }
    SignalSpy { id: undone; target: shortcuts; signalName: "undoRequested" }
    SignalSpy { id: tabbed; target: shortcuts; signalName: "tabRequested" }

    function init() {
        test.Window.window.requestActivate();
        tryVerify(function() { return test.Window.window.active; });
        shortcuts.enabled = true;
        shortcuts.studioActions = true;
        closed.clear(); undone.clear(); tabbed.clear();
        first.forceActiveFocus();
        verify(first.activeFocus);
    }

    function test_studio_actions_follow_control_focus() {
        second.forceActiveFocus();
        verify(second.activeFocus);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        tryCompare(undone, "count", 1);
        const keys = [Qt.Key_1, Qt.Key_2, Qt.Key_3, Qt.Key_4];
        const tabs = ["colors", "position", "presets", "shelf"];
        for (let i = 0; i < keys.length; ++i) {
            keyClick(keys[i]);
            tryCompare(tabbed, "count", i + 1);
            compare(tabbed.signalArguments[i][0], tabs[i]);
        }
        keyClick(Qt.Key_Escape);
        tryCompare(closed, "count", 1);
        verify(second.activeFocus);
    }

    function test_tab_traverses_controls() {
        keyClick(Qt.Key_Tab);
        tryCompare(second, "activeFocus", true);
        compare(closed.count, 0);
        compare(undone.count, 0);
        compare(tabbed.count, 0);
    }

    function test_popover_only_claims_escape() {
        shortcuts.studioActions = false;
        second.forceActiveFocus();
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        keyClick(Qt.Key_1);
        compare(undone.count, 0);
        compare(tabbed.count, 0);
        keyClick(Qt.Key_Escape);
        tryCompare(closed, "count", 1);
    }

    function test_hidden_editor_does_not_handle_keys() {
        shortcuts.enabled = false;
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        keyClick(Qt.Key_2);
        compare(closed.count, 0);
        compare(undone.count, 0);
        compare(tabbed.count, 0);
    }
}
