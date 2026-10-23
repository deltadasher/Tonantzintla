import QtQuick

// The outer item is a contained bounding box; children occupy its rotated face.
Item {
    id: root
    property int placementRotation: 0
    property real placementOpacity: 1
    readonly property real presentationWidth: face.width
    readonly property real presentationHeight: face.height
    default property alias instruments: face.data
    Item {
        id: face
        objectName: "instrumentFace"
        anchors.centerIn: parent
        width: root.placementRotation % 180 === 0 ? root.width : root.height
        height: root.placementRotation % 180 === 0 ? root.height : root.width
        clip: true
        rotation: root.placementRotation
        opacity: root.placementOpacity
    }
}
