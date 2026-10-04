import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string label: ""
    property string suffix: ""
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias value: slider.value
    signal edited(real value)
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: root.label; color: Theme.moon; font.pixelSize: 12; font.family: Theme.fontText }
        Text { text: Math.round(slider.value) + root.suffix; color: Theme.accent; font.pixelSize: 12; font.family: Theme.fontMono }
    }
    Slider {
        id: slider
        Layout.fillWidth: true
        implicitHeight: 30
        Accessible.name: root.label
        onMoved: root.edited(value)
        background: Rectangle {
            x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth; height: 5; radius: 3; color: Theme.controlActive
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.accent }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 17; height: 17; radius: 9
            color: slider.pressed || slider.visualFocus ? Theme.moon : Theme.accent
        }
    }
}
