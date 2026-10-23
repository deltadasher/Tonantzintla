import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../.."
import "../../components"
Item {
    id:root
    property string selectedId:ToolboxState.notes.length?ToolboxState.notes[0].id:""
    readonly property var note:ToolboxState.notes.find(function(note) { return note.id===root.selectedId; }) || null
    property string draftBody:""
    property bool dirty:false
    onNoteChanged:if(!dirty)draftBody=note?note.body:""
    function focusPrimary() { body.forceActiveFocus(); }
    function save() { if(dirty && note) { saveDelay.stop();const value=draftBody;dirty=false;ToolboxState.updateNote(selectedId,{body:value}); } }
    function select(id) { save();selectedId=id;draftBody=note?note.body:"";dirty=false; }
    Component.onDestruction:save()
    Timer { id:saveDelay;interval:450;onTriggered:root.save() }
    ColumnLayout {
        anchors.fill:parent;spacing:10
        RowLayout {
            Layout.fillWidth:true
            Text { Layout.fillWidth:true;text:"Pinned notes";color:Theme.moon;font.family:Theme.fontDisplay;font.pixelSize:25 }
            ActionButton { text:"New note";enabled:ToolboxState.notes.length<20;onClicked: { root.save();root.selectedId=ToolboxState.addNote();body.forceActiveFocus(); } }
        }
        Text { Layout.fillWidth:true;text:"Saved locally · up to 20 notes, 4,096 characters each";color:Theme.muted;font.family:Theme.fontText;font.pixelSize:12;wrapMode:Text.Wrap }
        ListView {
            Layout.fillWidth:true;Layout.preferredHeight:ToolboxState.notes.length?Math.min(120,ToolboxState.notes.length*40):0
            clip:true;spacing:4
            model:ToolboxState.notes.slice().sort(function(a,b) { return Number(b.pinned)-Number(a.pinned); })
            delegate:ActionButton { required property var modelData;width:ListView.view.width;text:(modelData.pinned?"★ ":"")+(modelData.title || "Untitled note");selected:modelData.id===root.selectedId;onClicked:root.select(modelData.id) }
        }
        SettingTextField {
            Layout.fillWidth:true;visible:root.note!==null;label:"Title";value:root.note?root.note.title:""
            onCommitted:value => { if(root.note)ToolboxState.updateNote(root.selectedId,{title:value}); }
        }
        Rectangle {
            Layout.fillWidth:true;Layout.fillHeight:true;radius:Theme.radiusMedium;color:Theme.fieldRest;border.color:body.activeFocus?Theme.accent:Theme.line;clip:true
            ScrollView {
                anchors.fill:parent;anchors.margins:12
                TextArea {
                    id:body;enabled:root.note!==null;text:root.draftBody;placeholderText:root.note?"Write a note…":"Create a note to begin."
                    color:Theme.moon;placeholderTextColor:Theme.muted;selectionColor:Theme.accent;selectedTextColor:Theme.void_
                    font.family:Theme.fontText;font.pixelSize:15;wrapMode:TextEdit.Wrap;selectByMouse:true;background:null
                    Accessible.name:"Note text";activeFocusOnTab:true
                    onTextChanged: { if(text.length>4096)remove(4096,text.length);if(root.note && text!==root.draftBody) { root.draftBody=text;root.dirty=true;saveDelay.restart(); } }
                    onActiveFocusChanged:if(!activeFocus)root.save()
                }
            }
        }
        RowLayout {
            Layout.fillWidth:true
            ActionButton { text:root.note && root.note.pinned?"Unpin":"Pin";enabled:root.note!==null;onClicked: { root.save();ToolboxState.updateNote(root.selectedId,{pinned:!root.note.pinned}); } }
            ActionButton { text:"Delete note";destructive:true;enabled:root.note!==null;onClicked: { saveDelay.stop();root.dirty=false;ToolboxState.removeNote(root.selectedId);root.selectedId=ToolboxState.notes.length?ToolboxState.notes[0].id:""; } }
            Text { Layout.fillWidth:true;text:saveDelay.running?"Saving…":Settings.persistenceStatus;color:Theme.muted;font.family:Theme.fontText;font.pixelSize:11;wrapMode:Text.Wrap }
        }
    }
}
