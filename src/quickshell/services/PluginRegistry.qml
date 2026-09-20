pragma Singleton
import QtQuick

// Compatibility for existing local consumers; these are built-in features.
QtObject {
    readonly property var entries: FeatureRegistry.entries
    function toggle(id) { FeatureRegistry.toggle(id); }
}
