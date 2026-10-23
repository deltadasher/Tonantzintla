const {test}=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');const m={};vm.createContext(m);
vm.runInContext(fs.readFileSync('src/quickshell/services/KeyboardLayoutModel.js','utf8').replace(/^\.pragma.*\n/,''),m);
test('initial keyboard snapshot, switch and reconfiguration use documented Niri fields',()=>{
 let state=m.apply(m.empty(),{KeyboardLayoutsChanged:{keyboard_layouts:{names:['English (US)','Norwegian'],current_idx:0}}});
 assert.equal(m.currentName(state),'English (US)');
 state=m.apply(state,{KeyboardLayoutSwitched:{idx:1}});assert.equal(m.currentName(state),'Norwegian');
 state=m.apply(state,{KeyboardLayoutsChanged:{keyboard_layouts:{names:['German'],current_idx:0}}});
 assert.equal(m.currentName(state),'German');assert.equal(state.names.length,1);
});
test('unrelated compositor events preserve keyboard snapshot identity',()=>{
 const state=m.empty();for(const event of [{WindowsChanged:{windows:[]}},{WorkspacesChanged:{workspaces:[]}},{WindowFocusChanged:{id:7}},null])assert.equal(m.apply(state,event),state);
});
test('unknown indices never display a stale or incorrectly shifted layout',()=>{
 let state=m.apply(m.empty(),{KeyboardLayoutsChanged:{keyboard_layouts:{names:[null,'Norwegian'],current_idx:1}}});
 assert.equal(m.currentName(state),'Norwegian');
 for(const idx of [-1,2,1.5,'1',null,Infinity])assert.equal(m.currentName(m.apply(state,{KeyboardLayoutSwitched:{idx}})),'');
 assert.equal(m.currentName(m.apply(m.empty(),{KeyboardLayoutSwitched:{idx:0}})),'');
 assert.equal(m.currentName(m.apply(state,{KeyboardLayoutsChanged:null})), '');
});
test('state storage remains bounded for abnormal messages',()=>{
 const state=m.apply(m.empty(),{KeyboardLayoutsChanged:{keyboard_layouts:{names:Array(1000).fill('x'.repeat(1000)),current_idx:0}}});
 assert.equal(state.names.length,256);assert.equal(state.names[0].length,128);
});
