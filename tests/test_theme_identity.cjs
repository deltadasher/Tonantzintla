const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');const crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');const components=path.join(root,'src/quickshell/components');
const data={};vm.createContext(data);vm.runInContext(fs.readFileSync(path.join(components,'ThemeIdentities.js'),'utf8'),data);
const model={Data:data};vm.createContext(model);vm.runInContext(fs.readFileSync(path.join(components,'ThemeIdentity.js'),'utf8').replace(/^\.(pragma|import).*$/gm,''),model);
const mode={};vm.createContext(mode);vm.runInContext(fs.readFileSync(path.join(components,'ThemeMode.js'),'utf8').replace(/^\.pragma.*$/gm,''),mode);
test('approved fourteen identities resolve exactly; originals stay byte-for-byte',()=>{
 assert.equal(model.identities.length,14);
 for(const mark of model.identities){
  assert.equal(model.match(mark.color).id,mark.id);
  const svg=fs.readFileSync(path.join(root,'src/quickshell/assets/theme-marks',mark.id+'.svg'));
  assert.equal(crypto.createHash('sha256').update(svg).digest('hex'),mark.sha256,mark.id);
  assert.match(svg.toString(),/<svg/);
 }
});
test('manual mark is independent of accent; unknown ids safely retain Wabi Sabi',()=>{
 assert.equal(model.resolve('ruby','#83dad9').id,'ruby');
 assert.equal(model.resolve('auto','#83dad9').id,'ice-cube');
 assert.equal(model.resolve('../../file','#000000').id,'wabi-sabi');
 assert.equal(model.match('invalid').id,'wabi-sabi');
});
test('automatic chooses exact accent ahead of exact seed and ignores malformed colors',()=>{
 assert.equal(model.sourceColor('#010101','#ffffff','#e9b872'),'#010101');
 assert.equal(model.sourceColor('oops','#D11E40','#e9b872'),'#d11e40');
 assert.equal(model.sourceColor('','',''),'#e9b872');
 assert.equal(model.match('#080808').id,'ink');assert.equal(model.match('#555555').id,'cloud');
 assert.equal(model.match('#cccccc').id,'moon');assert.equal(model.match('#f9f9f9').id,'snowflake');
 assert.equal(model.match('#d02040').id,'ruby');assert.equal(model.match('#478052').id,'leaf');
});
test('dark marks prefer light surfaces and fixed mode wins; exact dark seed stays supported',()=>{
 for(const mark of model.identities) assert.equal(model.recommendedMode(mark.id,'#ffffff'),mark.light?'light':'dark');
 assert.equal(mode.resolve('auto','#010101',''),'light');assert.equal(mode.resolve('auto','#ffffff',''),'dark');
 assert.equal(mode.resolve('auto','#ffffff','#010101'),'light');
 assert.equal(mode.resolve('dark','#010101','','light'),'dark');
 assert.equal(mode.resolve('light','#ffffff','','dark'),'light');
 assert.equal(mode.resolve('auto','','','light'),'light');assert.equal(mode.resolve('auto','','','dark'),'dark');
});
