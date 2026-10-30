const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const units=vm.createContext({});
vm.runInContext(fs.readFileSync("src/quickshell/components/UnitConversion.js","utf8").replace(".pragma library",""),units);
const ctx=vm.createContext({Units:units});
vm.runInContext(fs.readFileSync('src/quickshell/modules/ephemeris/widgets/catalog/LauncherModel.js','utf8').replace(/^\.(?:pragma|import).*$/gm,''),ctx);
test('calculator precedence, powers, scientific functions and degree mode',()=>{
 assert.equal(typeof ctx.calculate,'function');
 for(const [text,want] of [['2+3*4',14],['(2+3)*4',20],['2^3^2',512],['-2^2',-4],['2^-2',.25],['sqrt(81)+3!',15],['1e3/4',250],['min(2,3)+max(4,1)',6]]) assert.equal(ctx.calculate(text,false,0).value,want,text);
 assert.ok(Math.abs(ctx.calculate('sin(90)',true,0).value-1)<1e-12);
 assert.equal(ctx.calculate('ans*2',false,7).value,14);
});
test('calculator rejects code, nonfinite answers, excessive input and malformed syntax',()=>{
 for(const text of ['this.constructor','alert(1)','1;2','2**3','sqrt(-1)','1/0','171!','(1+2','1 2','2+'.repeat(200),'('.repeat(40)+'1'+')'.repeat(40)]) assert.equal(ctx.calculate(text,false,0).ok,false,text);
});
test('existing launcher math remains copyable and does not evaluate arbitrary strings',()=>{
 assert.equal(ctx.evaluateMath('2+3*4').result,'14');
 assert.equal(ctx.evaluateMath('firefox'),null);
 assert.equal(ctx.evaluateMath('1/0'),null);
});
const model=vm.createContext({});const modelPath='src/quickshell/modules/tools/ToolboxModel.js';
if(fs.existsSync(modelPath)) vm.runInContext(fs.readFileSync(modelPath,'utf8').replace('.pragma library',''),model);
test('tool storage bounds notes and history while preserving stable note identity',()=>{
 assert.equal(typeof model.sanitize,'function');
 const s=model.sanitize({notes:Array.from({length:50},()=>({id:'same',title:'x'.repeat(100),body:'y'.repeat(9000),pinned:true})),history:Array.from({length:80},()=>({expression:'1+1',result:'2'}))});
 assert.equal(s.notes.length,20);assert.equal(s.history.length,30);assert.equal(new Set(s.notes.map(x=>x.id)).size,20);assert.equal(s.notes[0].body.length,4096);
 const id=s.notes[0].id;const updated=model.updateNote(s,id,{title:'Changed',body:'Words'});assert.equal(updated.notes[0].title,'Changed');assert.equal(updated.notes[0].id,id);
 assert.equal(model.removeNote(updated,id).notes.length,19);
});
const emoji=vm.createContext({});vm.runInContext(fs.readFileSync('src/quickshell/modules/tools/EmojiModel.js','utf8').replace('.pragma library',''),emoji);
test('emoji search matches names and glyphs and keyboard traversal wraps',()=>{
 assert.ok(emoji.search('cat').some(row=>row.emoji==='🐱'));
 assert.ok(emoji.search('🐱').some(row=>row.emoji==='🐱'));
 assert.equal(emoji.search('no-such-emoji-word').length,0);
 assert.equal(emoji.move(0,-1,10),9);assert.equal(emoji.move(9,1,10),0);assert.equal(emoji.move(0,1,0),-1);
});
