pragma Singleton
import QtQuick
import "../.."
import "ToolboxModel.js" as Model
QtObject {
    readonly property var state: Model.sanitize(Settings.toolboxState)
    readonly property var notes: state.notes
    readonly property var history: state.history
    function addNote() { Settings.toolboxState=Model.addNote(state);return notes.length?notes[0].id:""; }
    function updateNote(id,patch) { Settings.toolboxState=Model.updateNote(state,id,patch); }
    function removeNote(id) { Settings.toolboxState=Model.removeNote(state,id); }
    function remember(expression,result) { Settings.toolboxState=Model.remember(state,expression,result); }
    function clearHistory() { const next=Model.sanitize(state);next.history=[];Settings.toolboxState=next; }
}
