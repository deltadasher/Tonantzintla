const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const m={};vm.createContext(m);vm.runInContext(fs.readFileSync('src/quickshell/components/FeedbackPlacement.js','utf8').replace(/^\.pragma.*\n/,''),m);
test('legacy defaults and presets preserve centered edge placement',()=>{
 assert.deepEqual(JSON.parse(JSON.stringify(m.preset('bottom'))),{x:.5,y:1});
 assert.deepEqual(JSON.parse(JSON.stringify(m.preset('top-right'))),{x:1,y:0});
 assert.deepEqual(JSON.parse(JSON.stringify(m.preset('center'))),{x:.5,y:.5});
 const r=m.place(1920,1080,330,74,{top:24,bottom:24,left:24,right:24},.5,1);
 assert.equal(r.x,795);assert.equal(r.y,982);assert.equal(r.width,330);assert.equal(r.height,74);
});
test('custom positions clamp and respect actual per-edge output clearance',()=>{
 const r=m.place(1280,720,390,200,{top:70,bottom:14,left:60,right:14},99,-2);
 assert.equal(r.x,876);assert.equal(r.y,70);
 const p=m.normalized(r.x,r.y,r);assert.equal(p.x,1);assert.equal(p.y,0);
});
test('short narrow and malformed output data never produces offscreen windows',()=>{
 for (const [w,h] of [[320,180],[180,90],[40,30],[1,1],[NaN,Infinity]]) {
  for (const shape of [[330,74],[120,260],[520,600]]) {
   const r=m.place(w,h,...shape,{left:70,right:70,top:70,bottom:70},Infinity,NaN);
   assert.ok(r.width>0 && r.height>0 && Number.isFinite(r.x));
   assert.ok(r.x>=0 && r.y>=0 && r.x+r.width<=r.outputWidth+.001 && r.y+r.height<=r.outputHeight+.001);
  }
 }
});
test('drag conversion is reversible and keyboard travel clamps at edges',()=>{
 const r=m.place(1920,1080,390,160,{left:14,right:14,top:64,bottom:14},.27,.73);
 const p=m.normalized(r.x,r.y,r);assert.ok(Math.abs(p.x-.27)<.001 && Math.abs(p.y-.73)<.001);
 assert.equal(m.step(.99,.05),1);assert.equal(m.step(.01,-.05),0);
 assert.equal(m.notificationWidth(-1),240);assert.equal(m.notificationWidth(2000),520);assert.equal(m.notificationWidth(NaN),390);
});
