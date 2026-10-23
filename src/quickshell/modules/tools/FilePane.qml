import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
Item {
    id:root
    property string query:""
    property string directory:Quickshell.env("HOME") || "/"
    property string parentDirectory:"/"
    property var entries:[]
    property int selection:0
    property bool showHidden:false
    property string status:""
    readonly property var matches:entries.filter(function(entry) { return entry.name.toLowerCase().indexOf(root.query.toLowerCase().trim())>=0; })
    onMatchesChanged:selection=matches.length?0:-1
    function browse(path) {
        if(fetch.running) return;
        const command=["python3",Environment.script("toolbox-files.py"),path];if(showHidden)command.push("--hidden");
        fetch.command=command;fetch.running=true;status="Reading folder…";
    }
    function moveSelection(delta) { if(!matches.length)return;selection=((selection+delta)%matches.length+matches.length)%matches.length;list.positionViewAtIndex(selection,ListView.Contain); }
    function activateSelected() {
        if(selection<0 || selection>=matches.length || fetch.running || opener.running)return;
        const entry=matches[selection];
        if(entry.directory)browse(entry.path);
        else { opener.command=["xdg-open",entry.path];opener.running=true;status="Opening file…"; }
    }
    Component.onCompleted:browse(directory)
    Process {
        id:fetch
        stdout:StdioCollector { onStreamFinished: {
            try { const result=JSON.parse(text);if(!result.ok) { root.status=result.error || "Folder unavailable.";return; }root.entries=result.entries;root.directory=result.path;root.parentDirectory=result.parent;root.status=result.truncated?"Showing at most 500 entries; no subfolders are indexed.":result.entries.length+" entries · one folder at a time"; }
            catch(error) { root.status="Could not read this folder."; }
        } }
    }
    Process { id:opener;onExited:(code,status) => root.status=code===0?"Open request sent to the default app.":"No application could open this file." }
    ColumnLayout {
        anchors.fill:parent;spacing:8
        RowLayout {
            Layout.fillWidth:true
            ActionButton { text:"Up";enabled:!fetch.running && root.directory!==root.parentDirectory;onClicked:root.browse(root.parentDirectory) }
            ActionButton { text:"Home";enabled:!fetch.running;onClicked:root.browse(Quickshell.env("HOME") || "/") }
            ActionButton { text:"Hidden";selected:root.showHidden;enabled:!fetch.running;onClicked: { root.showHidden=!root.showHidden;root.browse(root.directory); } }
            ActionButton { text:"Refresh";enabled:!fetch.running;onClicked:root.browse(root.directory) }
        }
        Text { Layout.fillWidth:true;text:root.directory;color:Theme.moon;font.family:Theme.fontMono;font.pixelSize:12;elide:Text.ElideMiddle }
        ListView {
            id:list;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:4;model:root.matches
            delegate:ActionButton { required property var modelData;required property int index;width:ListView.view.width;text:(modelData.directory?"▸  ":"     ")+modelData.name;selected:root.selection===index;onClicked: { root.selection=index;root.activateSelected(); } }
            Text { anchors.centerIn:parent;visible:root.matches.length===0 && !fetch.running;text:root.query?"No matching files":"This folder is empty";color:Theme.muted;font.family:Theme.fontText }
        }
        Text { Layout.fillWidth:true;text:root.status;color:Theme.muted;font.family:Theme.fontText;font.pixelSize:11;wrapMode:Text.Wrap }
    }
}
