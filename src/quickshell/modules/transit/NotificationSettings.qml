import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import "../.."
import "../../components"
import "../../services"
import "../../components/FeedbackPlacement.js" as Placement

ColumnLayout {
    id: root
    spacing: 10
    Component.onCompleted: if(Settings.notificationSoundPath.length) Notifications.checkSound()
    FeedbackPositionEditor {
        Layout.fillWidth:true;label:"Custom notification placement"
        output:Quickshell.screens[0] || null
        custom:Settings.notificationCustomPosition;normalizedX:Settings.notificationX;normalizedY:Settings.notificationY
        legacyPosition:Settings.notificationPosition
        popupWidth:Placement.notificationWidth(Settings.notificationWidth);popupHeight:100
        edgeMargin:14
        occupiedExtraGap:0
        previewComponent: NotificationCard { appName:"Tonantzintla";summary:"Notification preview";body:"A silent placement miniature.";popup:false;enabled:false }
        onCustomToggled: function(enabled) { Settings.notificationCustomPosition=enabled; }
        onEdited: function(x,y) { Settings.notificationX=x;Settings.notificationY=y;Settings.notificationCustomPosition=true; }
    }
    DockSettingSlider {
        Layout.fillWidth:true;label:"Notification width";suffix:" px";from:240;to:520;stepSize:10
        value:Settings.notificationWidth;onEdited:value => Settings.notificationWidth=value
    }
    SettingToggle { Layout.fillWidth:true;label:"Right-click to dismiss";checked:Settings.notificationRightClickClose;onToggled:Settings.notificationRightClickClose=!checked }
    SettingToggle { Layout.fillWidth:true;label:"Show empty-history artwork";checked:Settings.notificationEmptyGraphic;onToggled:Settings.notificationEmptyGraphic=!checked }
    SettingToggle {
        Layout.fillWidth:true;label:"Notification sounds"
        detail:"Optional local PCM WAV, up to 5 seconds / 8 MiB. Local previews stay silent."
        checked:Settings.notificationSoundsEnabled
        onToggled:Settings.notificationSoundsEnabled=!checked
    }
    FileDialog {
        id: soundPicker
        title:"Choose notification sound";fileMode:FileDialog.OpenFile
        nameFilters:["PCM WAV sound (*.wav)"]
        onAccepted: { Settings.notificationSoundPath=selectedFile.toString();Notifications.checkSound(); }
    }
    Flow {
        Layout.fillWidth:true;spacing:6
        ActionButton { text:"Choose local sound…";onClicked:soundPicker.open() }
        ActionButton { text:"Check sound support";pending:Notifications.soundBusy;onClicked:Notifications.checkSound() }
        ActionButton { text:"Silent popup preview";onClicked:Notifications.preview("Notification preview","Placement and width preview; no sound is played.") }
    }
    SettingTextField {
        Layout.fillWidth:true;label:"Local WAV file";value:Settings.notificationSoundPath
        onCommitted: function(value) { Settings.notificationSoundPath=value;Notifications.checkSound(); }
    }
    DockSettingSlider {
        Layout.fillWidth:true;label:"Notification sound volume";suffix:"%";from:0;to:100;stepSize:1
        value:Settings.notificationSoundVolume*100;onEdited:value => Settings.notificationSoundVolume=value/100
    }
    Text { Layout.fillWidth:true;text:Notifications.soundStatus;wrapMode:Text.Wrap;color:Notifications.soundState === "error"?Theme.danger:Theme.muted;font.family:Theme.fontText;font.pixelSize:11 }
}
