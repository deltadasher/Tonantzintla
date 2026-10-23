import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
Item {
    id:root
    implicitHeight:content.implicitHeight
    property var observed:({})
    property string status:"Refresh reads available keyboard LEDs and radio state once. Automatic status requires a compositor event integration; no poller is started."
    function refresh() { if(!reader.running) { reader.running=true;status="Reading device state…"; } }
    Process {
        id:reader;command:["python3",Environment.script("osd-status.py")]
        stdout:StdioCollector { onStreamFinished: { try { root.observed=JSON.parse(text);root.status="Current device state. Missing or inconsistent hardware interfaces are shown as unsupported."; }catch(error) {root.status="Device state is unavailable.";} } }
    }
    ColumnLayout {
        id:content;width:parent.width;spacing:10
        SettingChoice {
            Layout.fillWidth:true;label:"OSD position";value:Settings.osdPosition
            choices:[{label:"Bottom",value:"bottom"},{label:"Top",value:"top"},{label:"Left",value:"left"},{label:"Right",value:"right"},{label:"Center",value:"center"}]
            onSelected: function(value) { Settings.osdPosition=value;Settings.osdCustomPosition=false; }
        }
        SettingChoice {
            Layout.fillWidth:true;label:"OSD orientation";value:Settings.osdOrientation
            choices:[{label:"Horizontal",value:"horizontal"},{label:"Vertical",value:"vertical"}]
            onSelected:value => Settings.osdOrientation=value
        }
        FeedbackPositionEditor {
            Layout.fillWidth:true;label:"Custom OSD placement"
            custom:Settings.osdCustomPosition;normalizedX:Settings.osdX;normalizedY:Settings.osdY;legacyPosition:Settings.osdPosition
            popupWidth:Settings.osdOrientation === "vertical" ? 120 : 330
            popupHeight:Settings.osdOrientation === "vertical" ? 260 : 74
            previewComponent: OsdBody { presentation:1 }
            onCustomToggled: function(enabled) { Settings.osdCustomPosition=enabled; }
            onEdited: function(x,y) { Settings.osdX=x;Settings.osdY=y;Settings.osdCustomPosition=true; }
        }
        SettingToggle { Layout.fillWidth:true;label:"Caps Lock status";checked:Settings.osdCapsLock;onToggled:Settings.osdCapsLock=!checked }
        SettingToggle { Layout.fillWidth:true;label:"Num Lock status";checked:Settings.osdNumLock;onToggled:Settings.osdNumLock=!checked }
        SettingToggle { Layout.fillWidth:true;label:"Airplane mode status";checked:Settings.osdAirplane;onToggled:Settings.osdAirplane=!checked }
        Flow {
            Layout.fillWidth:true;spacing:8
            ActionButton { text:"Refresh actual state";pending:reader.running;onClicked:root.refresh() }
            ActionButton { text:"Preview OSD";onClicked:Osd.show("volume",65,"Preview · Volume",false) }
        }
        Repeater {
            model:[{id:"capslock",name:"Caps Lock"},{id:"numlock",name:"Num Lock"},{id:"airplane",name:"Airplane mode"}]
            RowLayout {
                required property var modelData
                Layout.fillWidth:true
                Text { Layout.fillWidth:true;text:parent.modelData.name+": "+(!root.observed[parent.modelData.id]?"Not checked":!root.observed[parent.modelData.id].supported?"Unsupported":root.observed[parent.modelData.id].enabled?"On":"Off");color:Theme.muted;font.family:Theme.fontText;font.pixelSize:12;wrapMode:Text.Wrap }
                ActionButton { text:"Show status";enabled:!!root.observed[parent.modelData.id] && root.observed[parent.modelData.id].supported;onClicked:Osd.showStatus(parent.modelData.id,root.observed[parent.modelData.id].enabled) }
                ActionButton { text:"Preview";onClicked:Osd.previewStatus(parent.modelData.id) }
            }
        }
        Text { Layout.fillWidth:true;text:root.status;color:Theme.muted;font.family:Theme.fontText;font.pixelSize:12;wrapMode:Text.Wrap }
    }
}
