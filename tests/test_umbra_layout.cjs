const {test}=require('node:test'); const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');const m={};
vm.createContext(m);vm.runInContext(fs.readFileSync('src/quickshell/modules/umbra/UmbraLayout.js','utf8').replace(/^\.pragma.*\n/,''),m);
test('malformed and extreme rectangles stay normalized and contained',()=>{
 for(const value of [null,[],{}, {clock:{x:9,y:-4,w:3,h:NaN}}, {battery:{x:Infinity,w:-3,visible:'false'}}]) {
  const out=m.normalize(value);assert.equal(Object.keys(out).length,5);
  for(const r of Object.values(out)){assert.ok(r.x>=0&&r.y>=0&&r.w>0&&r.h>0);assert.ok(r.x+r.w<=1&&r.y+r.h<=1);assert.equal(typeof r.visible,'boolean');}
 }
});
test('update is immutable and resizing reclamps position',()=>{
 const before=m.normalize({});const after=m.update(before,'clock',{x:.9,w:.7,visible:false});
 assert.equal(before.clock.x,.045);assert.equal(after.clock.x,1-.7);assert.equal(after.clock.visible,false);
});
test('history retains only one hundred independent snapshots',()=>{
 let history=[];for(let i=0;i<130;i++)history=m.push(history,{clock:{x:i/200}});
 assert.equal(history.length,100);assert.equal(history[99].clock.x,.56);
});
test('appearance values normalize and survive editing without moving legacy rectangles',()=>{
 const base=m.normalize({}); assert.equal(base.clock.opacity,1); assert.equal(base.clock.rotation,0);
 const next=m.update(base,'clock',{opacity:.35,rotation:90});
 assert.equal(next.clock.opacity,.35); assert.equal(next.clock.rotation,90); assert.equal(next.clock.x,.045);
 const bad=m.normalize({clock:{opacity:Infinity,rotation:NaN},media:{opacity:-2,rotation:-90}});
 assert.equal(bad.clock.opacity,1); assert.equal(bad.clock.rotation,0); assert.equal(bad.media.opacity,0); assert.equal(bad.media.rotation,270);
});
test('quarter turn preserves physical size and clamps rotated bounds on wide and tall outputs',()=>{
 for(const [w,h] of [[1600,900],[900,1600]]) {
  const start=m.normalize({media:{x:.88,y:.9,w:.2,h:.1}});
  const next=m.rotate(start,'media',w,h); const r=next.media;
  assert.equal(r.rotation,90); assert.ok(Math.abs(r.w*w-.1*h)<1e-8); assert.ok(Math.abs(r.h*h-.2*w)<1e-8);
  assert.ok(r.x>=0&&r.y>=0&&r.x+r.w<=1.000001&&r.y+r.h<=1.000001);
 }
});
test('grid and sibling alignment return visible guide coordinates with contained geometry',()=>{
 const state=m.normalize({clock:{x:.1,y:.1,w:.2,h:.2},weather:{x:.6,y:.7,w:.2,h:.1}});
 const grid=m.snap(state,'weather',.234,.317,1000,500,true);
 assert.equal(grid.rect.x,.24); assert.equal(grid.rect.y,.32);
 const aligned=m.snap(state,'weather',.107,.69,1000,500,false);
 assert.equal(aligned.rect.x,.1); assert.equal(aligned.guideX,.1);
 const edge=m.snap(state,'weather',9,9,1000,500,false);
 assert.equal(edge.rect.x,.8); assert.equal(edge.rect.y,.9);
});
test('opposite resize edge remains stable and minimum size never crosses it',()=>{
 const original=m.normalize({media:{x:.2,y:.3,w:.4,h:.2}}).media;
 const resized=m.resize(original,'left',.1,0,1000,500,false);
 assert.ok(Math.abs(resized.x-.3)<1e-8);assert.ok(Math.abs(resized.w-.3)<1e-8);
 const tiny=m.resize(original,'left',.9,0,1000,500,false);
 assert.ok(Math.abs(tiny.x+tiny.w-.6)<1e-8);assert.ok(tiny.w>=.035);
});
test('partial oversized legacy rectangles clamp their fallback positions too',()=>{
 for (const key of m.keys) {
  const r=m.normalize({[key]:{w:.8,h:.65}})[key];
  assert.ok(r.x+r.w<=1 && r.y+r.h<=1,key);
 }
});
