import QtQuick
import Caelestia.Blobs
import ".."

// Local experiment backed by Caelestia's GPL Caelestia.Blobs QML plugin.
// The plugin performs the actual circular smooth-min SDF union; this file only
// binds Tonantzintla's source and destination geometry into its two BlobRects.
Item {
    id: root
    property var geometry: null
    property rect origin: Qt.rect(0, 0, 0, 0)
    property bool anchored: false

    BlobGroup {
        id: blobGroup
        color: Theme.void_
        smoothing: 24
        cornerFill: true
    }

    BlobRect {
        group: blobGroup
        visible: root.anchored
        x: root.origin.x
        y: root.origin.y
        width: root.origin.width
        height: root.origin.height
        radius: Math.min(10, height / 2)
        deformScale: 0.0005
    }

    BlobRect {
        group: blobGroup
        x: root.geometry ? root.geometry.x : 0
        y: root.geometry ? root.geometry.y : 0
        width: root.geometry ? root.geometry.width : 0
        height: root.geometry ? root.geometry.height : 0
        radius: root.geometry ? root.geometry.radius : 0
        deformScale: 0.00015
    }
}
