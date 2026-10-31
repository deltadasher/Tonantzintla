import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    property string islandId: "clock"
    property string currentZone: "center"
    property bool placementControls: false
    signal openRequested(string panel)
    signal moveRequested(string zone)
    signal arrangeRequested()
    signal removeRequested()
    readonly property bool supportsDensity: ["clock", "system_stats", "media"].indexOf(islandId) >= 0
    spacing: 8
    function setDensity(value) {
        const copy = Object.assign({}, Settings.islandDensity);
        if(value === "inherit") delete copy[islandId]; else copy[islandId] = value;
        Settings.islandDensity = copy;
    }
    function toggleMetric(id) {
        let metrics=Settings.barTelemetryMetrics.slice();
        const index=metrics.indexOf(id);
        if(index>=0) metrics.splice(index,1); else metrics.push(id);
        // Keep at least one channel, and keep its order independent of toggle order.
        if(metrics.length) Settings.barTelemetryMetrics=["cpu","memory","gpu","disk"].filter(function(key){return metrics.indexOf(key)>=0;});
    }
    SettingChoice {
        visible: root.supportsDensity; Layout.fillWidth: true
        label: "Spacing"; value: Settings.islandDensity[root.islandId] || "inherit"
        choices: [{label:"Use default",value:"inherit"},{label:"Compact",value:"compact"},{label:"Comfortable",value:"comfortable"}]
        onSelected: value => root.setDensity(value)
    }
    Loader {
        Layout.fillWidth: true
        sourceComponent: root.islandId === "clock" ? clockControls : root.islandId === "system_stats" ? statsControls : root.islandId === "media" ? mediaControls : root.islandId === "launcher" ? launcherControls : root.islandId === "status" ? statusControls : null
    }
    ActionButton {
        Layout.fillWidth: true
        visible: ["clock", "system_stats", "status", "media", "workspaces", "launcher"].indexOf(root.islandId)>=0
        text: "Open " + ({clock:"calendar",system_stats:"system stats",status:"system",media:"Resonance",workspaces:"workspaces",launcher:"launcher"}[root.islandId] || "panel")
        onClicked: root.openRequested(({clock:"calendar",system_stats:"system",status:"system",media:"media",workspaces:"workspaces",launcher:"apps"})[root.islandId])
    }
    SettingChoice {
        visible:root.placementControls;Layout.fillWidth:true;label:"Position in bar";value:root.currentZone
        choices:[{label:"Start",value:"start"},{label:"Center",value:"center"},{label:"End",value:"end"}]
        onSelected:value=>root.moveRequested(value)
    }
    RowLayout {
        visible:root.placementControls;Layout.fillWidth:true
        ActionButton {Layout.fillWidth:true;text:"Move and arrange";onClicked:root.arrangeRequested()}
        ActionButton {text:"Remove";destructive:true;onClicked:root.removeRequested()}
    }
    Component {
        id: clockControls
        ColumnLayout {
            spacing:8
            SettingChoice {
                Layout.fillWidth:true;label:"Clock face";value:Settings.barClockFace
                choices:[{label:"Classic",value:"classic"},{label:"Stacked",value:"stacked"},{label:"Compact",value:"compact"}]
                onSelected:value=>Settings.barClockFace=value
            }
            SettingChoice {Layout.fillWidth:true;label:"Time format";value:Settings.clock12h;choices:[{label:"24 hour",value:false},{label:"12 hour",value:true}];onSelected:value=>Settings.clock12h=value}
            SettingToggle {Layout.fillWidth:true;label:"Seconds";checked:Settings.showSeconds;onToggled:Settings.showSeconds=!checked}
            SettingToggle {Layout.fillWidth:true;label:"Date in classic face";checked:Settings.showDate;onToggled:Settings.showDate=!checked}
            SettingChoice {Layout.fillWidth:true;label:"Temperature";value:Settings.temperatureUnit;choices:[{label:"Celsius",value:"celsius"},{label:"Fahrenheit",value:"fahrenheit"}];onSelected:value=>Settings.temperatureUnit=value}

        }
    }
    Component {
        id: statsControls
        ColumnLayout {
            spacing:8
            SettingChoice {
                Layout.fillWidth:true;label:"Stats style";value:Settings.barTelemetryFace
                choices:[{label:"Numbers",value:"numeric"},{label:"Arc",value:"arc"},{label:"Graph",value:"trace"}]
                onSelected:value=>Settings.barTelemetryFace=value
            }
            Repeater {
                model:[{id:"cpu",label:"CPU usage"},{id:"memory",label:"Memory usage"},{id:"gpu",label:"GPU temperature"},{id:"disk",label:"Disk usage"}]
                SettingToggle {
                    required property var modelData
                    Layout.fillWidth:true;label:modelData.label
                    checked:Settings.barTelemetryMetrics.indexOf(modelData.id)>=0
                    enabled:!checked||Settings.barTelemetryMetrics.length>1
                    onToggled:root.toggleMetric(modelData.id)
                }
            }
            SettingToggle {Layout.fillWidth:true;label:"Show system stats";checked:Settings.showSystemStats;onToggled:Settings.showSystemStats=!checked}
            SettingToggle {Layout.fillWidth:true;label:"Show volume";checked:Settings.showAudio;onToggled:Settings.showAudio=!checked}
            Text {Layout.fillWidth:true;text:"Uses current system stats. Graph shows up to 16 recent changes while visible.";wrapMode:Text.Wrap;color:Theme.muted;font.family:Theme.fontText;font.pixelSize:Theme.textCaption}
        }
    }
    Component {
        id: mediaControls
        ColumnLayout {
            spacing:8
            DockSettingSlider {Layout.fillWidth:true;label:"Media width";suffix:" px";from:180;to:480;stepSize:10;value:Settings.barMediaWidth;onEdited:value=>Settings.barMediaWidth=Math.round(value)}
            SettingToggle {Layout.fillWidth:true;label:"Album artwork";checked:Settings.barMediaShowArt;onToggled:Settings.barMediaShowArt=!checked}
            SettingToggle {Layout.fillWidth:true;label:"Playback buttons";checked:Settings.barMediaShowControls;onToggled:Settings.barMediaShowControls=!checked}
            Repeater {
                model:[{key:"showMedia",label:"Show in bar"},{key:"showMediaProgress",label:"Progress bar"},{key:"showMediaTime",label:"Elapsed time"}]
                SettingToggle {required property var modelData;Layout.fillWidth:true;label:modelData.label;checked:Settings[modelData.key];onToggled:Settings[modelData.key]=!checked}
            }
            Text {Layout.fillWidth:true;text:Media.available?Media.title+" — "+Media.artist:"No active media player";elide:Text.ElideRight;color:Theme.muted;font.family:Theme.fontText;font.pixelSize:Theme.textCaption}
            RowLayout {
                Layout.fillWidth:true
                ActionButton {Layout.fillWidth:true;text:"Previous";enabled:Media.available&&Media.player.canGoPrevious;onClicked:Media.previous()}
                ActionButton {Layout.fillWidth:true;text:Media.playing?"Pause":"Play";enabled:Media.available&&Media.player.canTogglePlaying;onClicked:Media.toggle()}
                ActionButton {Layout.fillWidth:true;text:"Next";enabled:Media.available&&Media.player.canGoNext;onClicked:Media.next()}
            }
        }
    }
    Component {
        id: statusControls
        ColumnLayout {
            spacing:8
            Repeater {
                model:[{key:"showBattery",label:"Battery"},{key:"showBluetooth",label:"Bluetooth"},{key:"showMicrophone",label:"Microphone"},{key:"showBrightness",label:"Brightness"}]
                SettingToggle {required property var modelData;Layout.fillWidth:true;label:modelData.label;checked:Settings[modelData.key];onToggled:Settings[modelData.key]=!checked}
            }
            Text {Layout.fillWidth:true;text:"Volume · "+Audio.percent+"%";color:Theme.muted;font.family:Theme.fontMono;font.pixelSize:Theme.textCaption}
            RowLayout {
                Layout.fillWidth:true
                ActionButton {Layout.fillWidth:true;text:"−5%";onClicked:Audio.change(-5)}
                ActionButton {Layout.fillWidth:true;text:"+5%";onClicked:Audio.change(5)}
                ActionButton {Layout.fillWidth:true;text:Audio.muted?"Unmute":"Mute";onClicked:Audio.toggleMute()}
            }
        }
    }
    Component {
        id: launcherControls
        ColumnLayout {
            spacing:8
            SettingToggle {Layout.fillWidth:true;label:"Automatic launcher width";checked:Settings.launcherWidth===0;onToggled:Settings.launcherWidth=checked?720:0}
            DockSettingSlider {Layout.fillWidth:true;enabled:Settings.launcherWidth>0;label:"Launcher width";suffix:" px";from:480;to:1000;stepSize:20;value:Settings.launcherWidth||720;onEdited:value=>Settings.launcherWidth=Math.round(value)}
            SettingToggle {Layout.fillWidth:true;label:"Automatic result count";checked:Settings.launcherVisibleRows===0;onToggled:Settings.launcherVisibleRows=checked?6:0}
            DockSettingSlider {Layout.fillWidth:true;enabled:Settings.launcherVisibleRows>0;label:"Visible result rows";from:3;to:10;stepSize:1;value:Settings.launcherVisibleRows||6;onEdited:value=>Settings.launcherVisibleRows=Math.round(value)}
        }
    }
}
