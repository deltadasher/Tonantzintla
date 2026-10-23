const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const m={};vm.createContext(m);vm.runInContext(fs.readFileSync('src/quickshell/components/IconFontGlyphs.js','utf8').replace(/^\.pragma.*\n/,''),m);
const manifest=JSON.parse(fs.readFileSync('src/assets/fonts/glyphs.json','utf8'));
test('every bundled Unicode scalar resolves; unknown and excluded strings preserve configured fallback',()=>{
 for(const value of manifest.codepoints) assert.equal(m.covers(String.fromCodePoint(value)),true,value.toString(16));
 for(const value of [...Object.keys(manifest.system_fallback).map(Number),0xf0001,0x10ffff]) {
  assert.equal(m.covers(String.fromCodePoint(value)),false);
  assert.equal(m.covers('A'+String.fromCodePoint(value)),false);
 }
 assert.equal(m.covers(''),true);assert.equal(m.covers('123'),true);
 assert.equal(manifest.codepoints.filter(v=>v>=0xf0000).length,17);
});
