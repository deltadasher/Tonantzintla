const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync('docs/threshold.js', 'utf8');
function setup({ reduced = false, stored = false, blocked = false, width = 1280, height = 720 } = {}) {
  const nodes = new Map();
  function element(name) {
    if (!nodes.has(name)) nodes.set(name, {
      style: {}, attrs: {}, events: {}, hidden: false, inert: false,
      clientWidth: width, clientHeight: height, offsetWidth: Math.min(width * .52, 520),
      classList: { values: new Set(), add(x) { this.values.add(x); }, contains(x) { return this.values.has(x); } },
      querySelector: element, setAttribute(k,v) { this.attrs[k] = v; },
      addEventListener(k,v) { this.events[k] = v; }, removeEventListener(k) { delete this.events[k]; },
      getAnimations: () => [], focus() { this.focused = true; }
    });
    return nodes.get(name);
  }
  const content = [element('header'), element('main'), element('footer')];
  const root = element('html'); root.style.overflow = '';
  const motion = element('motion'); motion.matches = reduced;
  let pending, written = false, requests = 0;
  const sandbox = {
    document: { querySelector: element, querySelectorAll: () => content, documentElement: root, activeElement: element('.threshold-hole') },
    window: element('window'), matchMedia: () => motion,
    sessionStorage: { getItem() { if(blocked) throw Error(); return stored ? '1' : null; }, setItem() { if(blocked) throw Error(); written = true; } },
    requestAnimationFrame(fn) { pending = fn; return ++requests; }, cancelAnimationFrame() { pending = null; },
  };
  vm.runInNewContext(source, sandbox);
  return { element, content, root, motion, click() { element('.threshold-hole').events.click(); },
    step(t) { const fn = pending; pending = null; fn(t); }, pending: () => pending, written: () => written, requests: () => requests };
}
for (const size of [[1280,720],[390,844],[1920,1080]]) {
  const s = setup({width:size[0],height:size[1]});
  assert(s.content.every(e => e.inert));
  s.click(); s.click(); assert.equal(s.requests(),1, 'rapid click creates one clock');
  s.step(0);
  for (const time of [300,800,1036,1400,1800]) {
    s.step(time);
    const d = s.element('.threshold-sheet.top').attrs.d;
    assert(!/NaN|Infinity/.test(d));
    const edge = s.element('.threshold-edge.top').attrs.d;
    assert(d.startsWith(edge), 'cut and sheet use identical boundary');
  }
  s.step(1850);
  assert(s.element('#threshold').hidden);
  assert(s.content.every(e => !e.inert));
  assert.equal(s.root.style.overflow,'');
  assert.equal(s.pending(),null);
  assert(s.written());
  assert(s.element('.site-tab').focused);
}
for (const blocked of [false,true]) {
  const s=setup({reduced:true,blocked});s.click();
  assert(s.element('#threshold').hidden);assert.equal(s.requests(),0);
}
const resumed=setup({stored:true});assert(resumed.element('#threshold').hidden);assert.equal(resumed.root.style.overflow,'');
const changed=setup();changed.click();changed.motion.matches=true;changed.motion.events.change();assert.equal(changed.pending(),null);assert(changed.element('#threshold').hidden);
const resized=setup();resized.click();resized.step(0);resized.element('#threshold').clientWidth=390;resized.element('window').events.resize();resized.step(900);assert.equal(resized.element('.threshold-peel').attrs.viewBox,'0 0 390 720');
console.log('Threshold: geometry, rapid click, resize, completion, focus, reduced motion, and blocked storage passed.');
