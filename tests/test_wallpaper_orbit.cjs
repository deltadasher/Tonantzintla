const {test}=require('node:test'), assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const orbit={};vm.createContext(orbit);vm.runInContext(fs.readFileSync('src/quickshell/components/WallpaperOrbit.js','utf8').replace(/^\.pragma.*\n/,''),orbit);
const entry=n=>({path:`/${n}.png`,name:String(n),kind:'image',preview:`/${n}.png`});
test('current is found anywhere in the full library, independent of filter order',()=>{
 const library=Array.from({length:20},(_,i)=>entry(i));
 assert.equal(orbit.current(library,'/19.png','image').name,'19');
 const sampled=orbit.sample(library.slice(0,5),library[19],8,()=>0);
 assert.equal(sampled[0].path,'/19.png');assert.equal(sampled.length,6);
});
test('an unindexed current still remains previewable; a video is not decoded as an image',()=>{
 assert.equal(orbit.current([],'/outside.png','image').preview,'/outside.png');
 assert.equal(orbit.current([],'/clip.mp4','video').preview,undefined);
 assert.equal(orbit.current([],'','image'),null);
});
test('sampling changes neighbors rather than rotating a sorted sequence',()=>{
 const library=Array.from({length:12},(_,i)=>entry(i));
 let n=0;const random=()=>[.8,.1,.9,.3,.7,.2][n++%6];
 const sampled=orbit.sample(library,library[0],8,random).map(e=>e.path);
 assert.equal(sampled[0],'/0.png');assert.equal(sampled.length,8);
 const indices=Array.from(sampled.slice(1),path=>Number(path.match(/\d+/)[0]));
 assert.ok(indices.some((value,i)=>i>0 && value!==indices[i-1]+1));
 assert.equal(library.map(e=>e.name).join(','),'0,1,2,3,4,5,6,7,8,9,10,11');
});
test('duplicate paths and file URLs do not repeat the current wallpaper',()=>{
 const current=entry(0),list=[current,{...current,path:'file:///0.png'},entry(1),entry(1)];
 const sampled=orbit.sample(list,current,8,()=>0);
 assert.equal(sampled.length,2);assert.equal(new Set(sampled.map(orbit.key)).size,2);
});
test('empty, singleton, and absent-current libraries remain bounded',()=>{
 assert.equal(orbit.sample([],null,8).length,0);
 assert.equal(orbit.sample([entry(0)],entry(0),8).length,1);
 assert.equal(orbit.sample(Array.from({length:30},(_,i)=>entry(i)),null,8).length,8);
});
