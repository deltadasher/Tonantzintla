const assert=require('node:assert/strict');
const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');
let checks=0;
function luminance(hex) {
 const cs=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);
 return cs[0]*.2126+cs[1]*.7152+cs[2]*.0722;
}
for(const tree of ['src']) {
 const file=path.resolve(__dirname,'..',tree,'quickshell/components/ThemeMode.js');
 let source=fs.readFileSync(file,'utf8').replace(/^\.pragma library\s*/,'');
 const ctx=vm.createContext({});vm.runInContext(source,ctx);
 for(const [color,expected] of [['#000000','#ffffff'],['#ffffff','#000000'],['#757575','#ffffff'],['#767676','#000000'],['#FF0000','#000000'],['#0000ff','#ffffff'],['bad','#ffffff']]) {
  assert.equal(ctx.foreground(color),expected);checks++;
 }
 for(let n=0;n<256;n++) {
  const hex='#'+n.toString(16).padStart(2,'0').repeat(3);
  const chosen=ctx.foreground(hex);const lum=luminance(hex);
  const contrast=chosen==='#000000'?(lum+.05)/.05:1.05/(lum+.05);
  assert(contrast>=4.5,`${tree} ${hex} ${contrast}`);checks++;
 }
}
console.log(`${checks} accent foreground checks passed`);
