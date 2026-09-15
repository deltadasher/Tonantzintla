const {readFileSync}=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
(async()=>{
function el(attrs={}) {return {attrs,events:{},dataset:{},hidden:false,addEventListener(k,f){this.events[k]=f},getAttribute(k){return this.attrs[k]},setAttribute(k,v){this.attrs[k]=v},focus(){this.focused=true}}}
const panels=Array.from({length:5},()=>el());
const tabs=panels.map((p,i)=>el({'aria-controls':'panel-'+i}));
const tones=['amber','lilac','mint'].map(t=>{const b=el();b.dataset.tone=t;return b});
const status=el(),copy=el(),watch=el(),close=el();
const code={textContent:'  echo example\n'};let copied,paused=false;
const video={play(){return Promise.reject(Error('blocked'))},pause(){paused=true}};
const dialog=el();dialog.querySelector=s=>s==='video'?video:close;dialog.showModal=()=>dialog.open=true;dialog.close=()=>{dialog.open=false;dialog.events.close()};
const body={dataset:{}};let manual=false;
const document={body,querySelectorAll:s=>s==='[data-instrument]'?tabs:s==='.swatches button[data-tone]'?tones:[],getElementById:id=>panels[Number(id.split('-')[1])],querySelector:s=>({'#demo-dialog':dialog,'[data-watch]':watch,'#copy-install':copy,'#install-commands':code,'#copy-status':status}[s]),createRange:()=>({selectNodeContents(){}})};
const navigator={clipboard:{writeText:async text=>copied=text}};
vm.runInNewContext(readFileSync('docs/site.js','utf8'),{document,navigator,window:{getSelection:()=>({removeAllRanges(){},addRange(){manual=true}})}});
tabs[3].events.click();assert.equal(tabs[3].attrs['aria-selected'],'true');assert.equal(panels.filter(p=>!p.hidden).length,1);assert(!panels[3].hidden);
tabs[3].events.keydown({key:'End',preventDefault(){}});assert(tabs[4].focused);assert(!panels[4].hidden);
tabs[4].events.keydown({key:'ArrowRight',preventDefault(){}});assert(tabs[0].focused);assert(!panels[0].hidden);
tones[1].events.click();assert.equal(body.dataset.tone,'lilac');assert.equal(tones[1].attrs['aria-pressed'],'true');
watch.events.click();assert(dialog.open);close.events.click();assert(!dialog.open);assert(paused);
await copy.events.click();assert.equal(copied,'echo example');assert(status.textContent.startsWith('Copied'));
navigator.clipboard.writeText=async()=>{throw Error('denied')};await copy.events.click();assert(manual);assert(status.textContent.includes('unavailable'));
console.log('Site: tab selection/keyboard wrap, accent state, video close, clipboard success and fallback passed.');
})().catch(e=>{console.error(e);process.exitCode=1});
