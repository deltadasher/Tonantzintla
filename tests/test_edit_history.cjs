const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const ctx = vm.createContext({});
const file = path.join(__dirname, '../src/quickshell/components/EditHistory.js');
if (fs.existsSync(file)) vm.runInContext(fs.readFileSync(file,'utf8').replace('.pragma library',''),ctx);
const plain = x => JSON.parse(JSON.stringify(x));
const a = {horizontal:'a',vertical:'b',placements:'{}',dockEnabled:false,dockOutput:'one'};
const b = {horizontal:'c',vertical:'d',placements:'{"two":1}',dockEnabled:true,dockOutput:'two'};
const c = {...b,horizontal:'e'};
test('undo and redo restore both orientations and dock configuration together',()=>{
 let h=ctx.create(); h=ctx.record(h,a,b); h=ctx.record(h,b,c);
 let r=ctx.undo(h,c); assert.deepEqual(plain(r.state),b);
 r=ctx.undo(r.history,b); assert.deepEqual(plain(r.state),a);
 r=ctx.redo(r.history,a); assert.deepEqual(plain(r.state),b);
 r=ctx.redo(r.history,b); assert.deepEqual(plain(r.state),c);
});
test('no-op edits preserve redo; new edits discard it',()=>{
 let r=ctx.undo(ctx.record(ctx.create(),a,b),b);
 let h=ctx.record(r.history,a,a); assert.equal(h.future.length,1);
 h=ctx.record(h,a,c); assert.equal(h.future.length,0);
 assert.deepEqual(plain(ctx.undo(h,c).state),a);
});
test('external changes cannot be overwritten by stale undo or redo',()=>{
 let h=ctx.record(ctx.create(),a,b);
 let r=ctx.undo(h,c); assert.equal(r.state,null); assert.equal(r.history.past.length,0);
 r=ctx.undo(h,b); r=ctx.redo(r.history,c); assert.equal(r.state,null);
});
test('history is bounded and snapshots do not alias mutable callers',()=>{
 let h=ctx.create(); let before={n:0};
 for(let n=1;n<=60;n++){let after={n}; h=ctx.record(h,before,after); before=after;}
 assert.equal(h.past.length,50); before.n=99;
 let r=ctx.undo(h,{n:60}); assert.deepEqual(plain(r.state),{n:59});
});
