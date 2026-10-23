const {test}=require('node:test'), assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const m={};vm.createContext(m);vm.runInContext(fs.readFileSync('src/quickshell/modules/umbra/UmbraFingerprintState.js','utf8').replace(/^\.pragma.*\n/,''),m);
test('visual state reports actual fingerprint operation and never invents scan progress',()=>{
 assert.equal(m.state(false,'password',false,false),'ready');
 assert.equal(m.state(true,'password',false,false),'ready');
 assert.equal(m.state(false,'password',true,false),'ready');
 assert.equal(m.state(true,'fingerprint',false,false),'pending');
 assert.equal(m.state(false,'fingerprint',true,false),'failed');
 assert.equal(m.state(false,'fingerprint',false,true),'success');
});
