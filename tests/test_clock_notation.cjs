const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),m={};
vm.createContext(m);vm.runInContext(fs.readFileSync('src/quickshell/components/ClockNotation.js','utf8').replace(/^\.pragma.*\n/,''),m);
test('global minute notation includes unambiguous noon and midnight, without adding second polling',()=>{
 for(const [h,expected] of [[0,'12:07 am'],[12,'12:07 pm'],[13,'1:07 pm'],[23,'11:07 pm']]) {
  const d=new Date(2026,9,21,h,7,49);
  assert.equal(m.time(d,true),expected);
  assert.equal(m.time(d,false),String(h).padStart(2,'0')+':07');
  assert.equal(m.stacked(d,true),expected.split(' ')[0].replace(':','\n'));
  assert.equal(m.period(d,true),h<12?'am':'pm');
  assert.equal(m.period(d,false),'');
 }
});
