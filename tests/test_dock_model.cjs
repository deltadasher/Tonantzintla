const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../src/quickshell/components/DockModel.js'), 'utf8').replace('.pragma library', ''), ctx);
const plain = value => JSON.parse(JSON.stringify(value));
const apps = [{id:'org.browser.desktop',name:'Browser',icon:'browser',startupClass:'Browser'},
    {id:'terminal.desktop',name:'Terminal'}];
const windows = [{id:3,app_id:'Browser'},{id:1,app_id:'org.browser'},{id:2,app_id:'terminal'}];
test('icon overrides normalize desktop IDs and retain fallback for invalid values', () => {
    const entry = {appId:'Browser.desktop',icon:'original'};
    assert.equal(ctx.iconFor(entry, '{"browser":" custom "}'), 'custom');
    for (const raw of ['{', 'null', '[]', '{"browser":3}', '{"browser":" "}'])
        assert.equal(ctx.iconFor(entry, raw), 'original');
});
test('pins sanitize malformed, duplicate and unsupported values', () => {
    assert.deepEqual(plain(ctx.pins('{')), []);
    assert.deepEqual(plain(ctx.pins('{}')), []);
    assert.deepEqual(plain(ctx.pins('["A.desktop","a",null,12,"", "b"]')), ['A.desktop','b']);
});
test('desktop suffix and startup class group windows without duplicates', () => {
    const rows = ctx.entries(apps,windows,['org.browser.desktop'],true);
    assert.deepEqual(plain(rows.map(e=>[e.id,e.windows])), [['org.browser',[1,3]],['terminal',[2]]]);
    assert.equal(rows[0].app,apps[0]);
});
test('pinned ordering survives focus and window event order', () => {
    const saved = ['terminal.desktop','org.browser.desktop'];
    assert.deepEqual(plain(ctx.entries(apps,windows,saved,true)),plain(ctx.entries(apps,windows.slice().reverse(),saved,true)));
});
test('hide running keeps pinned running indicators and missing pins', () => {
    const rows = ctx.entries(apps,windows,['org.browser.desktop','removed.desktop'],false);
    assert.equal(rows.length,2);
    assert.equal(rows[1].app,null);
    assert.equal(rows[0].windows.length,2);
});
test('window activation cycles and handles focus outside group', () => {
    assert.equal(ctx.nextWindow([1,3],1),3);
    assert.equal(ctx.nextWindow([1,3],3),1);
    assert.equal(ctx.nextWindow([1,3],5),1);
    assert.equal(ctx.nextWindow([],5),-1);
});
test('pin reorder clamps boundaries and keeps missing id unchanged', () => {
    assert.equal(ctx.movePin('["a","b"]','a',1),'["b","a"]');
    assert.equal(ctx.movePin('["a","b"]','a',-1),'["a","b"]');
    assert.equal(ctx.movePin('["a","b"]','c',1),'["a","b"]');
});
