const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const palette={};vm.createContext(palette);
try { vm.runInContext(fs.readFileSync('src/quickshell/components/SpectralPalette.js','utf8').replace(/^\.pragma.*\n/,''),palette); } catch(error) { palette.loadError=error.message; }
test('spectral colors are opaque six-channel overrides with bounded storage',()=>{
 assert.equal(typeof palette.sanitize,'function',palette.loadError);
 const clean=palette.sanitize({accent:'#AACCFF',cyan:'#72d9e7',rose:'#ec8eae',unknown:'#ffffff',danger:'red',success:'#12345678'});
 assert.deepEqual(JSON.parse(JSON.stringify(clean)),{accent:'#aaccff',cyan:'#72d9e7',rose:'#ec8eae'});
 assert.deepEqual(JSON.parse(JSON.stringify(palette.sanitize(['#ffffff']))),{});
});
test('unreadable or malformed edits preserve the applied role, reset removes only that role',()=>{
 assert.equal(typeof palette.edit,'function',palette.loadError);
 const initial={accent:'#a99cff',cyan:'#72d9e7'};
 for(const value of ['#090a12','rgba(0,0,0,0)','url(file:///tmp/x)','bad']) {
  const result=palette.edit(initial,'accent',value,'#080910');assert.equal(result.ok,false);assert.deepEqual(JSON.parse(JSON.stringify(result.colors)),initial);
 }
 const accepted=palette.edit(initial,'accent','#FFFFFF','#080910');assert.equal(accepted.ok,true);assert.equal(accepted.colors.accent,'#ffffff');
 const reset=palette.edit(initial,'accent','','#080910');assert.equal(reset.ok,true);assert.deepEqual(JSON.parse(JSON.stringify(reset.colors)),{cyan:'#72d9e7'});
 assert.equal(palette.edit(initial,'unknown','#ffffff','#080910').ok,false);
});
test('adaptive backing revalidates overrides instead of preserving unreadable text',()=>{
 assert.equal(typeof palette.resolve,'function',palette.loadError);
 assert.equal(palette.resolve({accent:'#ffffff'},'accent','#a99cff','#080910'),'#ffffff');
 assert.equal(palette.resolve({accent:'#ffffff'},'accent','#111111','#eeeeee'),'#111111');
 assert.equal(palette.resolve({accent:'#ffffff'},'danger','#ed7d8f','#080910'),'#ed7d8f');
 assert.ok(Math.abs(palette.contrast('#ffffff','#000000')-21)<.00001);
 assert.ok(palette.contrast('#a99cff','#080910')>=4.5);
});

test('semantic colors must remain legible on every ordinary instrument backing',()=>{
 const surfaces=['#080910','#10121d','#171a28'];
 assert.ok(palette.contrast('#797979',surfaces[0])>=4.5);
 assert.ok(palette.contrast('#797979',surfaces[2])<4.5);
 assert.equal(palette.edit({},'accent','#797979',surfaces).ok,false);
 assert.equal(palette.edit({},'accent','#a99cff',surfaces).ok,true);
 assert.equal(palette.resolve({accent:'#797979'},'accent','#a99cff',surfaces),'#a99cff');
});
