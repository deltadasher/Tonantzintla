const {test}=require('node:test'), assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const live={};vm.createContext(live);vm.runInContext(fs.readFileSync('src/quickshell/components/LiveScenes.js','utf8').replace(/^\.pragma.*\n/,''),live);
test('every live scene has a component, a bundled still and integer sliders',()=>{
 assert.ok(live.scenes.length>=4);
 for(const scene of live.scenes){
  assert.ok(fs.existsSync(path.join('src/quickshell/components/live',scene.component)),scene.id+' component');
  assert.ok(fs.existsSync(path.join('src/assets/wallpapers/live',scene.id+'.png')),scene.id+' still');
  for(const prop of scene.props){
   assert.ok(prop.from<prop.to&&prop.value>=prop.from&&prop.value<=prop.to,scene.id+'.'+prop.name+' default in range');
   assert.equal(typeof prop.suffix,'string');assert.ok(Number.isInteger(prop.step)&&prop.step>0);
  }
 }
});
test('library entries are images of their still plus a scene id',()=>{
 const entries=live.entries('/root/live');
 assert.equal(entries.length,live.scenes.length);
 const snow=entries.find(entry=>entry.liveId==='snow');
 assert.deepEqual({...snow},{path:'/root/live/snow.png',preview:'/root/live/snow.png',name:'Snowfall',source:'Live',kind:'live',liveId:'snow'});
 assert.equal(live.idForPath('/root/live','/root/live/snow.png'),'snow');
 assert.equal(live.idForPath('/root/live','/root/live/other.png'),'');
 assert.equal(live.idForPath('/root/live',''),'');
});
test('values overlay saved settings on defaults and stay inside each range',()=>{
 const snow=live.find('snow');
 assert.equal(live.values(snow,{}).density,350);
 assert.equal(live.values(snow,{snow:{density:900}}).density,900);
 assert.equal(live.values(snow,{snow:{density:99999,wind:'gale'}}).density,1200);
 assert.equal(live.values(snow,{snow:{wind:'gale'}}).wind,1);
 assert.equal(live.values(snow,{snow:{wind:0}}).wind,0);
 assert.deepEqual({...live.values(null,{})},{});
});
test('saving and resetting never mutates the previous settings object',()=>{
 const before={life:{cell:12}};
 const after=live.withValue(before,'snow','wind',-3);
 assert.deepEqual(before,{life:{cell:12}});
 assert.deepEqual(JSON.parse(JSON.stringify(after)),{life:{cell:12},snow:{wind:-3}});
 assert.deepEqual(JSON.parse(JSON.stringify(live.without(after,'life'))),{snow:{wind:-3}});
 assert.deepEqual(JSON.parse(JSON.stringify(live.withValue(undefined,'flow','pace',2))),{flow:{pace:2}});
});
