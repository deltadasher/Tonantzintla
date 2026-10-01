/* Dependency-free controller/lifecycle tests. A WebGL fixture proves calls and
 * state sequencing, not shader compilation, visual quality or GPU hardware. */
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync('docs/gravity-scene.js', 'utf8');

function setup(options = {}) {
  const calls = [], raf = new Map(), nodes = new Map();
  let nextId = 0, intersection, resize;
  function node(id) {
    if (nodes.has(id)) return nodes.get(id);
    const classes = new Set();
    const n = {
      id, dataset: {}, style: {}, attrs: {}, events: {}, hidden: false,
      textContent: '', disabled: false, clientWidth: options.width || 800,
      clientHeight: options.height || 600, width: 0, height: 0,
      classList: {add: (...names) => names.forEach(x => classes.add(x)),
        remove: (...names) => names.forEach(x => classes.delete(x)),
        contains: name => classes.has(name),
        toggle(name, force) { const on = force ?? !classes.has(name); on ? classes.add(name) : classes.delete(name); return on; }},
      addEventListener(type, fn) { (this.events[type] ||= []).push(fn); },
      removeEventListener(type, fn) { this.events[type] = (this.events[type] || []).filter(x => x !== fn); },
      setAttribute(name, value) { this.attrs[name] = String(value); },
      getAttribute(name) { return this.attrs[name] ?? null; },
      getBoundingClientRect() { return {x:0, y:0, top:0, left:0, right:this.clientWidth, bottom:this.clientHeight, width:this.clientWidth, height:this.clientHeight}; },
      querySelector(selector) { return node(selector.replace(/^#/, '')); },
      setPointerCapture(id) { calls.push(['capture', id]); },
      releasePointerCapture(id) { calls.push(['release', id]); },
      hasPointerCapture() { return true; },
      focus() {}, closest() { return null; },
    };
    nodes.set(id, n); return n;
  }
  const constants = {VERTEX_SHADER:35633, FRAGMENT_SHADER:35632, COMPILE_STATUS:35713,
    LINK_STATUS:35714, ARRAY_BUFFER:34962, STATIC_DRAW:35044, FLOAT:5126,
    TRIANGLES:4, TRIANGLE_STRIP:5, COLOR_BUFFER_BIT:16384, NO_ERROR:0};
  const gl = new Proxy(constants, {get(target, name) {
    if (name in target) return target[name];
    if (name === 'getShaderParameter') return shader => !options.compileFail &&
      !(options.fragmentCompileFail && shader.args[0] === constants.FRAGMENT_SHADER);
    if (name === 'getProgramParameter') return () => !options.linkFail;
    if (name === 'getShaderInfoLog' || name === 'getProgramInfoLog') return () => 'fixture shader error';
    if (name === 'getAttribLocation') return () => 0;
    if (name === 'getUniformLocation') return (_, uniform) => uniform;
    if (name === 'getExtension') return () => null;
    if (name === 'getParameter') return () => 4096;
    if (name === 'isContextLost') return () => false;
    if (name === 'getError') return () => options.glError ? 1282 : 0;
    return (...args) => {
      calls.push([name, ...args]);
      if (name.startsWith('create')) return {type:name,args};
      if (options.drawFail && (name === 'drawArrays' || name === 'drawElements')) throw Error('fixture draw failure');
    };
  }});
  const canvas = node('gravity-canvas');
  canvas.getContext = type => { calls.push(['getContext', type]); if(options.contextThrows) throw Error('context refused'); return options.noWebGL || (options.webgl1 && type === 'webgl2') ? null : gl; };
  const stage = node('gravity-stage');
  canvas.parentElement = stage;
  const motion = node('motion'); motion.matches = !!options.reduced;
  const document = node('document'); document.hidden = !!options.hidden;
  document.visibilityState = options.hidden ? 'hidden' : 'visible';
  const threshold = node('threshold'); threshold.hidden = !options.intro;
  document.getElementById = id => options.missing && id === 'gravity-canvas' ? null : node(id);
  document.querySelector = selector => document.getElementById(selector.replace(/^#/, ''));
  const window = node('window'); window.devicePixelRatio = options.dpr || 1;
  window.innerWidth = options.width || 800; window.innerHeight = options.height || 600;
  window.matchMedia = () => motion;
  const requestAnimationFrame = callback => {raf.set(++nextId, callback); return nextId;};
  const cancelAnimationFrame = id => raf.delete(id);
  const IntersectionObserver = class {
    constructor(fn) {intersection = fn;} observe() {} unobserve() {} disconnect() {}
  };
  const ResizeObserver = class {
    constructor(fn) {resize = fn;} observe() {} disconnect() {}
  };
  window.IntersectionObserver = IntersectionObserver;
  window.ResizeObserver = ResizeObserver;
  window.requestAnimationFrame = requestAnimationFrame;
  window.cancelAnimationFrame = cancelAnimationFrame;
  const sandbox = {window, document, performance:{now:()=>0}, console:{warn:(...args)=>calls.push(['warn',...args])},
    matchMedia:()=>motion, requestAnimationFrame, cancelAnimationFrame,
    IntersectionObserver, ResizeObserver, Float32Array, Uint16Array,
    devicePixelRatio:window.devicePixelRatio, setTimeout: fn => {fn(); return 1;}, clearTimeout() {},
  };
  vm.runInNewContext(source, sandbox, {timeout:1000});
  const dispatch = (target, name, extra = {}) => {
    const event = {type:name, target, preventDefault(){this.prevented=true;}, ...extra};
    for(const fn of [...target.events[name] || []]) fn(event);
    return event;
  };
  return {calls, canvas, stage, motion, document, window, node, dispatch,
    draws:()=>calls.filter(call => ['drawArrays','drawElements'].includes(call[0])),
    pending:()=>raf.size,
    step(time=16) { const current = [...raf.values()]; raf.clear(); current.forEach(fn=>fn(time)); },
    intersect(value) { assert(intersection, 'visibility observer must exist'); intersection([{target:stage,isIntersecting:value,intersectionRatio:value?1:0}]); },
    resize() { if(resize) resize([{target:stage}]); else dispatch(window,'resize'); },
  };
}

const normal = setup();
assert.equal(normal.canvas.dataset.renderer, 'webgl');
assert.equal(normal.canvas.dataset.state, 'ready');
assert.equal(normal.canvas.dataset.context, 'webgl2');
assert.equal(normal.stage.tabIndex, 0);
assert.equal(normal.canvas.dataset.frames, '1');
assert(normal.stage.classList.contains('is-rendered'));
assert.equal(normal.draws().length, 1, 'ready follows a completed draw');
assert(normal.calls.some(c => c[0] === 'getContext' && c[1] === 'webgl2'));
assert.equal(normal.calls.filter(c => c[0] === 'compileShader').length, 2);
assert.equal(normal.calls.filter(c => c[0] === 'linkProgram').length, 1);
assert(normal.calls.some(c => c[0] === 'shaderSource' && c[2].includes('for(int i=0;i<192;i++)')), 'bounded GLSL ray-march is submitted');
assert.equal(normal.pending(), 1, 'one animation clock');
normal.step(100); assert.equal(normal.pending(), 1);
const at100 = normal.draws().length;
normal.step(116); assert.equal(normal.draws().length, at100, '30fps frame budget');
normal.step(140); assert.equal(normal.draws().length, at100 + 1);
for(const options of [{noWebGL:true}, {contextThrows:true}, {compileFail:true}, {fragmentCompileFail:true}, {linkFail:true}, {drawFail:true}, {glError:true}]) {
  const failed = setup(options);
  assert.equal(failed.canvas.dataset.state, 'fallback');
  assert.equal(failed.pending(), 0);
  assert.equal(failed.stage.tabIndex, -1, 'unavailable view is not a false keyboard interaction');
  assert.equal(failed.stage.attrs['aria-label'], 'Still black-hole view');
  assert(!failed.stage.classList.contains('is-rendered'));
  assert(failed.node('gravity-motion').disabled);
  assert(failed.node('gravity-reset').disabled);
  assert(failed.node('gravity-status').textContent.startsWith('Still view')); 
  for(const resource of ['Shader','Program','Buffer']) {
    assert.equal(failed.calls.filter(c => c[0] === 'delete'+resource).length,
      failed.calls.filter(c => c[0] === 'create'+resource).length,
      'failed initialization releases every allocated '+resource.toLowerCase());
  }
}
assert.equal(setup({missing:true}).pending(), 0, 'suite pages without a scene are safe');
const lateOptions = {}, late = setup(lateOptions); lateOptions.drawFail = true;
assert.doesNotThrow(() => late.step(100));
assert.equal(late.canvas.dataset.state, 'fallback');
assert.equal(late.pending(), 0, 'late draw failure stops its clock and exposes fallback');
assert.equal(late.calls.filter(c => c[0] === 'deleteProgram').length, 1,
  'late draw failure releases its linked program');
assert.equal(late.calls.filter(c => c[0] === 'deleteBuffer').length, 1,
  'late draw failure releases its vertex buffer');

const legacy = setup({webgl1:true});
assert.equal(legacy.canvas.dataset.context, 'webgl');
assert.equal(legacy.draws().length, 1);
const legacyShaders = legacy.calls.filter(c => c[0] === 'shaderSource').map(c=>c[2]);
assert(legacyShaders.some(s => s.includes('attribute vec2 position') && s.includes('varying vec2 uv')));
assert(legacyShaders.some(s => s.includes('gl_FragColor') && !s.includes('out vec4 color')));
assert(legacyShaders.every(s => !s.includes('#version 300 es')), 'WebGL1 receives compatible GLSL');
const frozen = setup();
frozen.dispatch(frozen.node('gravity-motion'), 'click');
assert.equal(frozen.pending(), 0);
assert.equal(frozen.node('gravity-motion').attrs['aria-pressed'], 'true');
const beforeDrag = frozen.draws().length;
frozen.dispatch(frozen.stage, 'pointerdown', {button:0,pointerId:4,clientX:100,clientY:100});
frozen.dispatch(frozen.stage, 'pointermove', {pointerId:4,clientX:180,clientY:160});
assert.equal(frozen.draws().length, beforeDrag + 1, 'paused scene still supports explicit exploration');
assert(frozen.calls.some(c => c[0] === 'uniform2f' && c[1] === 'rotation' && c[2] > -.16));
frozen.dispatch(frozen.stage, 'pointercancel', {pointerId:4});
assert(!frozen.stage.classList.contains('is-dragging'));
frozen.dispatch(frozen.node('gravity-reset'), 'click');
const rotations = frozen.calls.filter(c => c[0] === 'uniform2f' && c[1] === 'rotation');
assert.deepEqual(rotations.at(-1).slice(2), [-.16,-.06]);
const keyboard = frozen.dispatch(frozen.stage,'keydown',{key:'ArrowRight'});
assert(keyboard.prevented); assert.equal(frozen.pending(), 0);
assert(frozen.calls.filter(c => c[0] === 'uniform2f' && c[1] === 'rotation').at(-1)[2] > -.16);
const childKey = frozen.dispatch(frozen.stage,'keydown',{key:'ArrowRight',target:frozen.node('gravity-reset')});
assert(!childKey.prevented, 'child controls do not become camera shortcuts');
assert(!frozen.dispatch(frozen.stage,'keydown',{key:'Tab'}).prevented);
frozen.dispatch(frozen.node('gravity-motion'), 'click');
assert.equal(frozen.pending(), 1);

const interrupted = setup();
interrupted.intersect(false); assert.equal(interrupted.pending(), 0);
interrupted.intersect(true); assert.equal(interrupted.pending(), 1);
interrupted.document.hidden = true;
interrupted.dispatch(interrupted.document, 'visibilitychange'); assert.equal(interrupted.pending(), 0);
interrupted.document.hidden = false;
interrupted.dispatch(interrupted.document, 'visibilitychange'); assert.equal(interrupted.pending(), 1);
const loss = interrupted.dispatch(interrupted.canvas, 'webglcontextlost');
assert(loss.prevented, 'permit WebGL context restoration');
assert.equal(interrupted.pending(), 0);
assert.equal(interrupted.canvas.dataset.state, 'fallback');
assert(!interrupted.stage.classList.contains('is-rendered'));
interrupted.dispatch(interrupted.canvas, 'webglcontextrestored');
assert.equal(interrupted.canvas.dataset.state, 'ready');
assert.equal(interrupted.pending(), 1);
interrupted.dispatch(interrupted.window, 'pagehide', {persisted:true}); assert.equal(interrupted.pending(), 0);
interrupted.dispatch(interrupted.window, 'pageshow', {persisted:true}); assert.equal(interrupted.pending(), 1);
interrupted.dispatch(interrupted.window, 'pagehide', {persisted:false}); assert.equal(interrupted.pending(), 0);
interrupted.dispatch(interrupted.window, 'resize'); assert.equal(interrupted.pending(), 0, 'disposed page cannot restart');
const contextsBeforeRestore = interrupted.calls.filter(c => c[0] === 'getContext').length;
const drawsBeforeRestore = interrupted.draws().length;
interrupted.dispatch(interrupted.canvas, 'webglcontextrestored');
assert.equal(interrupted.calls.filter(c => c[0] === 'getContext').length, contextsBeforeRestore,
  'context restoration after final pagehide cannot allocate a new renderer');
assert.equal(interrupted.draws().length, drawsBeforeRestore);
assert.equal(interrupted.pending(), 0);
const disposed = setup();
disposed.dispatch(disposed.window, 'pagehide', {persisted:false});
assert.equal(disposed.calls.filter(c => c[0] === 'deleteProgram').length, 1);
assert.equal(disposed.calls.filter(c => c[0] === 'deleteBuffer').length, 1,
  'final pagehide releases GPU resources while BFCache pagehide retains them');

const entrance = setup({intro:true});
assert.equal(entrance.draws().length, 1, 'one complete still frame is allowed behind the entrance');
assert.equal(entrance.pending(), 0, 'covered scene must not animate behind the intro');
entrance.dispatch(entrance.document, 'tonantzintla:instrument', {detail:{id:'parallax'}});
entrance.dispatch(entrance.window, 'resize');
assert.equal(entrance.pending(), 0, 'background updates cannot restart covered motion');
entrance.node('threshold').hidden = true;
entrance.dispatch(entrance.document, 'tonantzintla:entered');
assert.equal(entrance.pending(), 1, 'finishing or skipping the intro starts exactly one scene clock');
entrance.dispatch(entrance.document, 'tonantzintla:entered');
assert.equal(entrance.pending(), 1, 'repeated completion events do not duplicate motion');
const quietEntrance = setup({intro:true,reduced:true});
quietEntrance.node('threshold').hidden = true;
quietEntrance.dispatch(quietEntrance.document, 'tonantzintla:entered');
assert.equal(quietEntrance.pending(), 0, 'entrance completion respects reduced motion');

const reduced = setup({reduced:true});
assert.equal(reduced.draws().length, 1);
assert.equal(reduced.pending(), 0);
assert(reduced.node('gravity-motion').disabled, 'reduced-motion control must not promise an ineffective resume');
assert.equal(reduced.node('gravity-motion').textContent, 'Reduced motion');
assert(reduced.stage.classList.contains('is-rendered'), 'reduced motion still has a complete sculpture');
reduced.dispatch(reduced.node('gravity-reset'), 'click'); assert.equal(reduced.pending(), 0);
reduced.dispatch(reduced.document, 'tonantzintla:instrument', {detail:{id:'umbra'}});
assert(reduced.calls.some(c => c[0] === 'uniform1f' && c[1] === 'instrument' && c[2] === 4));
reduced.dispatch(reduced.document, 'tonantzintla:instrument', {detail:{id:'unknown'}});
assert.equal(reduced.calls.filter(c => c[0] === 'uniform1f' && c[1] === 'instrument').at(-1)[2], 0);
const changed = setup(); changed.motion.matches = true; changed.dispatch(changed.motion,'change');
assert.equal(changed.pending(), 0);
assert.equal(changed.node('gravity-motion').attrs['aria-pressed'], 'true');
assert(changed.node('gravity-status').textContent.includes('reduced motion'));
const huge = setup({width:3840,height:2160,dpr:3});
assert(huge.canvas.width * huge.canvas.height < 361000, 'curved-ray pixel work remains bounded');
const tiny = setup({width:360,height:640,dpr:3});
assert(tiny.canvas.width <= 360 * 1.35);
assert(tiny.canvas.width * tiny.canvas.height < 181000, 'compact stages use the lower pixel budget');
const compactWide = setup({width:599,height:900,dpr:3});
assert(compactWide.canvas.width * compactWide.canvas.height < 181000);
assert(compactWide.canvas.width <= 599 * 1.35);
assert(!normal.stage.events.wheel, 'scene must not consume page scrolling');
console.log('Gravity scene: submitted GLSL/draw lifecycle, fallback, frame budget, pause/drag/reset, intro suspension, visibility, context recovery/disposal, reduced motion and pixel cap passed. Browser shader compilation and hardware backing are separate checks.');
