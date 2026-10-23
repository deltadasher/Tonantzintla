.pragma library
function text(value,max) { return typeof value==="string"?value.slice(0,max):""; }
function sanitize(raw) {
    raw=raw && typeof raw==="object" ? raw : {};
    const seen={};
    const notes=(Array.isArray(raw.notes)?raw.notes:[]).slice(0,20).map(function(note,index) {
        note=note || {};let id=text(note.id,48);
        if(!/^[a-z0-9_-]+$/i.test(id) || seen[id]) { let n=index+1;do {id="note-"+n++;}while(seen[id]); }
        seen[id]=true;
        return {id:id,title:text(note.title,80),body:text(note.body,4096),pinned:note.pinned!==false};
    });
    const history=(Array.isArray(raw.history)?raw.history:[]).slice(0,30).filter(function(row) { return row && typeof row.expression==="string" && typeof row.result==="string"; }).map(function(row) { return {expression:text(row.expression,256),result:text(row.result,80)}; });
    return {version:1,notes:notes,history:history};
}
function addNote(state) {
    const s=sanitize(state);if(s.notes.length>=20) return s;
    let n=1;while(s.notes.some(function(note) { return note.id==="note-"+n; }))n++;
    s.notes.unshift({id:"note-"+n,title:"Untitled note",body:"",pinned:true});return s;
}
function updateNote(state,id,patch) {
    const s=sanitize(state);s.notes=s.notes.map(function(note) { if(note.id!==id)return note;return {id:id,title:patch.title===undefined?note.title:patch.title,body:patch.body===undefined?note.body:patch.body,pinned:patch.pinned===undefined?note.pinned:patch.pinned}; });return sanitize(s);
}
function removeNote(state,id) { const s=sanitize(state);s.notes=s.notes.filter(function(note) {return note.id!==id;});return s; }
function remember(state,expression,result) {
    const s=sanitize(state);s.history=[{expression:text(expression,256),result:text(result,80)}].concat(s.history.filter(function(row) {return row.expression!==expression;})).slice(0,30);return s;
}
