const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync('docs/threshold.js', 'utf8');
function setup({ reduced = false, stored = false, blocked = false, width = 1280, height = 720,
  hash = '', noThreshold = false, noEnter = false, unrelatedFocus = false, noFocusTarget = false,
  arrival = null, overflow = '' } = {}) {
  const nodes = new Map();
  function element(name) {
    if (!nodes.has(name)) nodes.set(name, {
      style: {}, attrs: {}, events: {}, hidden: false, inert: false,
      clientWidth: width, clientHeight: height, offsetWidth: Math.min(width * .52, 520),
      classList: { values: new Set(), add(x) { this.values.add(x); }, contains(x) { return this.values.has(x); } },
      querySelector(selector) { return noEnter && selector === '.threshold-hole' ? null : element(selector); },
      setAttribute(k,v) { this.attrs[k] = v; },
      addEventListener(k,v) { this.events[k] = v; }, removeEventListener(k) { delete this.events[k]; },
      getAnimations: () => arrival ? [arrival] : [], focus() { this.focused = true; }
    });
    return nodes.get(name);
  }
  const content = [element('.skip-link'), element('header'), element('main'), element('footer')];
  const root = element('html'); root.style.overflow = overflow;
  const motion = element('motion'); motion.matches = reduced;
  const window = element('window'); window.location = {hash};
  let pending, written = false, requests = 0;
  const sandbox = {
    document: { querySelector(selector) {
      if ((noThreshold && selector === '#threshold') || (noFocusTarget && selector === '.site-tab')) return null;
      return element(selector);
    }, querySelectorAll: () => content, documentElement: root,
    activeElement: element(unrelatedFocus ? 'other' : '.threshold-hole') },
    window, matchMedia: () => motion,
    sessionStorage: { getItem() { if(blocked) throw Error(); return stored ? '1' : null; }, setItem() { if(blocked) throw Error(); written = true; } },
    requestAnimationFrame(fn) { pending = fn; return ++requests; }, cancelAnimationFrame() { pending = null; },
  };
  vm.runInNewContext(source, sandbox);
  return { element, content, root, motion, window, click() { element('.threshold-hole').events.click(); },
    escape(key = 'Escape') { let prevented = false; window.events.keydown({key, preventDefault() {prevented = true;}}); return prevented; },
    step(t) { const fn = pending; pending = null; assert.equal(typeof fn, 'function'); fn(t); },
    pending: () => pending, written: () => written, requests: () => requests };
}
(async () => {
  for (const size of [[1280,720],[360,640],[390,844],[1920,1080]]) {
    const s = setup({width:size[0],height:size[1],overflow:'auto'});
    assert(s.content.every(e => e.inert));
    s.click(); s.click(); assert.equal(s.requests(),1, 'rapid click creates one clock');
    s.step(0);
    for (const time of [300,800,1036,1400,1800]) {
      s.step(time);
      for (const half of ['top', 'bottom']) {
        const d = s.element('.threshold-sheet.' + half).attrs.d;
        assert(!/NaN|Infinity/.test(d));
        const edge = s.element('.threshold-edge.' + half).attrs.d;
        assert(d.startsWith(edge), 'cut and sheet use identical boundary');
      }
    }
    s.step(1850);
    assert(s.element('#threshold').hidden);
    assert(s.content.every(e => !e.inert));
    assert.equal(s.root.style.overflow,'auto');
    assert.equal(s.pending(),null);
    assert(s.written());
    assert(s.element('.site-tab').focused);
    assert.equal(s.window.events.resize, undefined);
    assert.equal(s.window.events.keydown, undefined);
    assert.equal(s.motion.events.change, undefined);
    s.click(); assert.equal(s.pending(),null, 'completed entrance cannot restart');
  }
  for (const blocked of [false,true]) {
    const s=setup({reduced:true,blocked});s.click();
    assert(s.element('#threshold').hidden);assert.equal(s.requests(),0);
  }
  for (const options of [{stored:true}, {hash:'#install'}, {hash:'#panel-parallax', blocked:true}]) {
    const resumed=setup(options);assert(resumed.element('#threshold').hidden);
    assert.equal(resumed.root.style.overflow,'');assert(resumed.content.every(e => !e.inert));
    assert.equal(resumed.window.events.keydown, undefined);assert.equal(resumed.written(),false);
  }
  for (const options of [{noThreshold:true}, {noEnter:true}]) {
    const missing=setup(options);assert.equal(missing.requests(),0);assert.equal(missing.root.style.overflow,'');
  }
  const changed=setup();changed.click();changed.motion.matches=true;changed.motion.events.change();
  assert.equal(changed.pending(),null);assert(changed.element('#threshold').hidden);
  const resized=setup();resized.click();resized.step(0);resized.element('#threshold').clientWidth=390;
  resized.window.events.resize();resized.step(900);
  assert.equal(resized.element('.threshold-peel').attrs.viewBox,'0 0 390 720');
  for (const inFlight of [false,true]) {
    const skipped=setup();assert.equal(skipped.escape('Tab'),false);assert(!skipped.element('#threshold').hidden);
    if (inFlight) { skipped.click();skipped.step(0); }
    assert(skipped.escape());assert(skipped.element('#threshold').hidden);assert.equal(skipped.pending(),null);
    assert(skipped.content.every(e => !e.inert));
  }
  const other=setup({unrelatedFocus:true});other.escape();assert(!other.element('.site-tab').focused);
  const absent=setup({noFocusTarget:true});absent.escape();assert(absent.element('#threshold').hidden);
  let resolveArrival;
  const arrival={playState:'running',finished:new Promise(resolve => {resolveArrival=resolve;})};
  const arriving=setup({arrival});arriving.click();assert.equal(arriving.requests(),0);assert(arriving.element('.threshold-hole').disabled);
  arrival.playState='finished';resolveArrival();await Promise.resolve();
  assert.equal(arriving.requests(),1);assert.equal(arriving.element('.threshold-hole').disabled,false);arriving.escape();
  const rejected=setup({arrival:{playState:'running',finished:Promise.reject(Error('animation cancelled'))}});
  rejected.click();await Promise.resolve();await Promise.resolve();assert(rejected.element('#threshold').hidden);
  console.log('Threshold: geometry, rapid clicks, resize, cleanup/focus, reduced motion, storage/hash bypass, Escape, missing elements, and arrival completion/cancellation passed.');
})().catch(error => {console.error(error);process.exitCode=1;});
