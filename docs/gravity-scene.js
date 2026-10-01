/* SPDX-License-Identifier: GPL-3.0-or-later
 * Tonantzintla's browser-native observatory study.
 * A sculpted, imperfect accretion stream, not an astronomical simulation.
 * The product's existing WabiSabiBlackHole mark remains the actual logo.
 */
(() => {
  'use strict';
  const canvas = document.getElementById('gravity-canvas');
  const stage = document.getElementById('gravity-stage');
  if (!canvas || !stage) return;
  const motionButton = document.getElementById('gravity-motion');
  const resetButton = document.getElementById('gravity-reset');
  const status = document.getElementById('gravity-status');
  const hint = document.getElementById('gravity-hint');
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
  const vertexSource = `#version 300 es
  in vec2 position;
  out vec2 uv;
  void main() { uv = position * .5 + .5; gl_Position = vec4(position, 0., 1.); }`;
  const fragmentSource = `#version 300 es
  precision highp float;
  in vec2 uv;
  out vec4 color;
  uniform vec2 resolution;
  uniform vec2 rotation;
  uniform float time;
  uniform float instrument;
  const float PI = 3.14159265;
  mat2 turn(float a) { float s=sin(a),c=cos(a); return mat2(c,-s,s,c); }
  // The rising far-side fold is grounded in the project's wabi-sabi stream.
  float stream(vec3 p) {
    float angle = atan(p.z, p.x);
    float radial = length(p.xz);
    float wave = sin(angle*3.+.65)*.055 + sin(angle*5.-.8)*.025;
    float rise = (.78 + instrument*.012) * .5 * (sqrt(p.z*p.z+.035)-p.z);
    float center = 1.47 + wave + sin(angle+1.2)*.10;
    float width = .26 + instrument*.012 + .06*sin(angle*2.-.7);
    float height = .025 + .012*(.5+.5*cos(angle*3.));
    float y = p.y + .19 - rise - sin(angle*2.+time*.085)*.035;
    vec2 q = abs(vec2(radial-center,y)) - vec2(width-.02,height-.02);
    float slab = length(max(q,0.)) + min(max(q.x,q.y),0.) - .02;
    // A small, separated lower lens is part of the original mark's identity.
    vec3 l=p; l.y += .69;
    float lower = length(vec2((length(l.xz)-1.16)*.70,l.y))-.027;
    lower = max(lower, .35-l.z);
    lower = max(lower, -.35-l.x);
    return min(slab, lower);
  }
  vec3 normalAt(vec3 p) {
    vec2 e=vec2(.006,0.);
    return normalize(vec3(stream(p+e.xyy)-stream(p-e.xyy),stream(p+e.yxy)-stream(p-e.yxy),stream(p+e.yyx)-stream(p-e.yyx)));
  }
  float sphereHit(vec3 ro,vec3 rd) {
    vec3 oc=ro-vec3(.035,.15,0.);
    float b=dot(oc,rd), c=dot(oc,oc)-.83*.83;
    float h=b*b-c;
    return h<0.?100.:max(0.,-b-sqrt(h));
  }
  float grain(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
  void main() {
    vec2 screen=(uv-.5)*vec2(resolution.x/resolution.y,1.);
    vec3 ro=vec3(0.,1.35,5.35);
    ro.yz=turn(rotation.y)*ro.yz;
    ro.xz=turn(rotation.x)*ro.xz;
    vec3 target=vec3(0.,.12,0.);
    vec3 fw=normalize(target-ro);
    vec3 right=normalize(cross(fw,vec3(0.,1.,0.)));
    vec3 up=cross(right,fw);
    vec3 rd=normalize(fw*2.95+right*screen.x*2.+up*screen.y*2.);
    float horizon=sphereHit(ro,rd);
    // Bound work to the sculpted stream's bounding sphere.
    float b=dot(ro,rd),h=b*b-dot(ro,ro)+2.55*2.55;
    vec3 bg=vec3(.0431,.0431,.0510);
    float ambient=exp(-dot(screen*vec2(.7,1.),screen*vec2(.7,1.))*3.);
    bg += vec3(.014,.009,.008)*ambient;
    if(h<0.) { color=vec4(bg,1.); return; }
    float t=max(0.,-b-sqrt(h));
    float end=min(-b+sqrt(h),horizon);
    float glow=0.; bool hit=false; vec3 p=ro+rd*t;
    for(int i=0;i<96;i++) {
      p=ro+rd*t;
      float d=stream(p);
      glow+=exp(-abs(d)*22.)*.005;
      if(d<.0045) { hit=true; break; }
      t+=max(d*.76,.009);
      if(t>end) break;
    }
    vec3 amber=vec3(1.,.58,.23);
    vec3 pale=vec3(1.,.88,.65);
    vec3 violet=vec3(.60,.55,.78);
    vec3 result=bg+amber*glow*.36;
    // Fine photographic fringe, confined to the actual event-horizon rim.
    vec3 toCenter=vec3(.035,.15,0.)-ro;
    float impact=length(toCenter-dot(toCenter,rd)*rd);
    float halo=exp(-abs(impact-.846)*42.);
    result+=mix(amber,violet,.22+instrument*.05)*halo*.20;
    if(horizon<100.) result=vec3(.004,.004,.006)+amber*halo*.055;
    if(hit && t<end) {
      float a=atan(p.z,p.x);
      float r=length(p.xz);
      vec3 n=normalAt(p);
      vec3 light=normalize(vec3(-1.5,3.,-1.8));
      float diffuse=.26+.74*max(dot(n,light),0.);
      float fresnel=pow(1.-abs(dot(n,-rd)),2.);
      // Concentric lanes shear with angle, carrying texture around the fold.
      float shear=a-time*.03;
      float turbulence=sin(a*3.+r*7.-time*.11)*.012+sin(a*7.-r*5.)*.008;
      float lanes=.5+.5*sin((r+turbulence)*112.+sin(shear*3.)*1.3);
      lanes=pow(lanes,10.);
      float fine=.5+.5*sin(r*357.+a*6.+sin(a*9.)*2.-time*.2);
      float mottled=.5+.5*sin(r*38.+a*5.+sin(a*11.+r*6.));
      float temperature=clamp((1.9-r)*.95,0.,1.);
      vec3 base=mix(vec3(.18,.075,.025),amber,.30+mottled*.24);
      base=mix(base,pale,temperature*.45);
      float doppler=.55+.45*pow(.5+.5*sin(a-.6),2.);
      result=base*(diffuse*.72+lanes*.58+fine*.085)*doppler;
      result+=pale*lanes*temperature*.36;
      float polished=pow(max(dot(n,normalize(light-rd)),0.),16.);
      result+=pale*polished*.72;
      result+=mix(amber,violet,instrument*.04)*fresnel*.19;
      result+=amber*glow*.12;
      result=1.-exp(-result*1.65);
    }
    float vignette=1.-smoothstep(.45,1.10,length(screen));
    result=mix(bg,result,vignette);
    result+=(grain(gl_FragCoord.xy)-.5)/255.;
    color=vec4(result,1.);
  }`;

  let gl, program, buffer, locations;
  let raf = 0, last = 0, elapsed = 0, frames = 0;
  let visible = true, lost = false, disposed = false;
  let frozen = reduced.matches;
  let yaw = -.16, pitch = -.06;
  let targetYaw = yaw, targetPitch = pitch;
  let selected = 0, targetSelected = 0;
  let drag = null, width = 0, height = 0;
  const canAnimate = () => !disposed && !lost && visible && !document.hidden && !frozen && !reduced.matches;
  function setStatus(text) { if (status) status.textContent = text; }
  function updateControls() {
    if (motionButton) {
      motionButton.setAttribute('aria-pressed', String(frozen));
      motionButton.textContent = !program || lost ? 'Still view' : reduced.matches ? 'Reduced motion' : frozen ? 'Resume motion' : 'Pause motion';
      motionButton.disabled = reduced.matches || lost || !program;
    }
    if (resetButton) resetButton.disabled = lost || !program;
  }
  function fallback(message) {
    cancelAnimationFrame(raf); raf = 0;
    drag = null;
    stage.classList.remove('is-dragging');
    stage.classList.remove('is-rendered');
    stage.tabIndex = -1;
    stage.setAttribute('aria-label','Still black-hole view');
    canvas.dataset.state = 'fallback';
    canvas.dataset.renderer = 'fallback';
    if (hint) hint.hidden = true;
    program = null;
    setStatus(message || 'Still view · interactive 3D is unavailable');
    updateControls();
  }
  function compile(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source); gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const error = gl.getShaderInfoLog(shader);
      gl.deleteShader(shader);
      throw new Error(error || 'Shader compilation failed');
    }
    return shader;
  }
  function initialize() {
    try {
      const attributes = { alpha: false, antialias: false, depth: false, stencil: false, powerPreference: 'low-power', preserveDrawingBuffer: false };
      gl = canvas.getContext('webgl2', attributes);
      const modern = Boolean(gl);
      if (!gl) gl = canvas.getContext('webgl', attributes);
      if (!gl) { fallback(); return; }
      // The same geometry also works on browsers with WebGL 1 only.
      const vsSource = modern ? vertexSource : vertexSource.replace('#version 300 es','').replace('in vec2 position','attribute vec2 position').replace('out vec2 uv','varying vec2 uv');
      const fsSource = modern ? fragmentSource : fragmentSource.replace('#version 300 es','').replace('in vec2 uv','varying vec2 uv').replace('out vec4 color;','').replace(/\bcolor\b/g,'gl_FragColor');
      const vs = compile(gl.VERTEX_SHADER, vsSource);
      const fs = compile(gl.FRAGMENT_SHADER, fsSource);
      program = gl.createProgram();
      gl.attachShader(program, vs); gl.attachShader(program, fs); gl.linkProgram(program);
      gl.deleteShader(vs); gl.deleteShader(fs);
      if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
      gl.useProgram(program);
      buffer = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);
      const position = gl.getAttribLocation(program, 'position');
      gl.enableVertexAttribArray(position); gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
      locations = {};
      ['resolution','rotation','time','instrument'].forEach(key => { locations[key] = gl.getUniformLocation(program,key); });
      lost = false;
      resize(); if (!draw()) return;
      if (gl.getError() !== gl.NO_ERROR) throw new Error('The first frame could not be drawn');
      // Mark ready only after the first complete draw, never just context creation.
      canvas.dataset.state = 'ready'; canvas.dataset.renderer = 'webgl';
      canvas.dataset.context = modern ? 'webgl2' : 'webgl';
      stage.classList.add('is-rendered');
      if (hint) hint.hidden = false;
      stage.tabIndex = 0;
      stage.setAttribute('aria-label','Explore the black hole. Drag or use arrow keys to change the view.');
      updateControls();
      setStatus(reduced.matches ? 'Still view · reduced motion' : 'Drag to change your view');
      schedule();
    } catch (error) {
      console.warn('Tonantzintla: using the still black-hole view.', error);
      fallback();
    }
  }
  function resize() {
    if (!gl || !program || lost) return;
    const rect = canvas.getBoundingClientRect();
    // The ray-marched composition is capped by both DPR and total pixel area.
    let ratio = Math.min(window.devicePixelRatio || 1, 1.65);
    const pixels = Math.max(1, rect.width * rect.height);
    ratio = Math.min(ratio, Math.sqrt(720000 / pixels));
    const w = Math.max(1,Math.round(rect.width*ratio));
    const h = Math.max(1,Math.round(rect.height*ratio));
    if (w !== width || h !== height) {
      width=w; height=h; canvas.width=w; canvas.height=h;
      gl.viewport(0,0,w,h);
    }
  }
  function draw() {
    if (!gl || !program || lost || disposed) return false;
    try {
      gl.useProgram(program);
      gl.uniform2f(locations.resolution,width,height);
      gl.uniform2f(locations.rotation,yaw,pitch);
      gl.uniform1f(locations.time,elapsed);
      gl.uniform1f(locations.instrument,selected);
      gl.drawArrays(gl.TRIANGLES,0,6);
      canvas.dataset.frames = String(++frames);
      return true;
    } catch (error) {
      console.warn('Tonantzintla: 3D rendering stopped; showing the still view.',error);
      fallback(frames ? 'Still view · 3D rendering paused' : undefined);
      return false;
    }
  }
  function schedule() {
    if (canAnimate() && program && !raf) raf=requestAnimationFrame(tick);
  }
  function tick(timestamp) {
    raf=0;
    if (!canAnimate() || !program) { last=0; return; }
    // 30fps target lowers GPU duty without reducing pointer responsiveness.
    if (last && timestamp-last<30) { schedule(); return; }
    const dt = last ? Math.min((timestamp-last)/1000,.08) : 0;
    last=timestamp; elapsed+=dt;
    const ease=1.-Math.exp(-dt*8.);
    yaw+=(targetYaw-yaw)*ease;
    pitch+=(targetPitch-pitch)*ease;
    selected+=(targetSelected-selected)*ease;
    draw(); schedule();
  }
  function requestDraw() {
    if (!program || lost) return;
    if (frozen || reduced.matches || !visible || document.hidden) {
      yaw=targetYaw; pitch=targetPitch; selected=targetSelected; draw();
    } else schedule();
  }
  function suspend() { cancelAnimationFrame(raf); raf=0; last=0; }
  motionButton?.addEventListener('click', () => {
    frozen=!frozen;
    updateControls();
    if (frozen) { suspend(); setStatus('Motion paused · drag to explore'); }
    else { setStatus(reduced.matches ? 'Still view · reduced motion' : 'Drag to change your view'); schedule(); }
  });
  resetButton?.addEventListener('click', () => {
    targetYaw=-.16; targetPitch=-.06;
    requestDraw();
    setStatus(frozen ? 'View reset · motion paused' : reduced.matches ? 'View reset · reduced motion' : 'View reset · drag to explore');
  });
  stage.addEventListener('pointerdown', event => {
    if (!program || lost || event.button!==0 || event.target.closest('button,a,input')) return;
    drag={id:event.pointerId,x:event.clientX,y:event.clientY,yaw:targetYaw,pitch:targetPitch};
    canvas.setPointerCapture?.(event.pointerId);
    stage.classList.add('is-dragging');
  });
  stage.addEventListener('pointermove', event => {
    if (!drag || event.pointerId!==drag.id) return;
    targetYaw=drag.yaw+(event.clientX-drag.x)*.004;
    targetPitch=Math.max(-.40,Math.min(.28,drag.pitch+(event.clientY-drag.y)*.0025));
    requestDraw();
  });
  function endDrag(event) {
    if (!drag || event.pointerId!==drag.id) return;
    if (canvas.hasPointerCapture?.(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    drag=null; stage.classList.remove('is-dragging');
  }
  stage.addEventListener('pointerup',endDrag);
  stage.addEventListener('pointercancel',endDrag);
  stage.addEventListener('keydown', event => {
    if (event.target !== stage || !program || lost) return;
    const arrows = ['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'];
    if (!arrows.includes(event.key)) return;
    event.preventDefault();
    if (event.key === 'ArrowLeft') targetYaw -= .12;
    if (event.key === 'ArrowRight') targetYaw += .12;
    if (event.key === 'ArrowUp') targetPitch = Math.max(-.40,targetPitch-.055);
    if (event.key === 'ArrowDown') targetPitch = Math.min(.28,targetPitch+.055);
    requestDraw();
  });
  canvas.addEventListener('lostpointercapture', () => { drag=null; stage.classList.remove('is-dragging'); });
  document.addEventListener('tonantzintla:instrument', event => {
    const ids=['aperture','ephemeris','parallax','resonance','umbra'];
    targetSelected=Math.max(0,ids.indexOf(event.detail?.id));
    requestDraw();
  });
  function motionChange() {
    if (reduced.matches) { frozen=true; suspend(); setStatus('Still view · reduced motion'); }
    else setStatus(frozen ? 'Motion paused · drag to explore' : 'Drag to change your view');
    updateControls(); requestDraw();
  }
  reduced.addEventListener?.('change',motionChange);
  document.addEventListener('visibilitychange', () => { if(document.hidden) suspend(); else { resize(); requestDraw(); } });
  window.addEventListener('resize', () => { resize(); requestDraw(); }, {passive:true});
  const resizeObserver = typeof ResizeObserver==='function' ? new ResizeObserver(() => { resize(); requestDraw(); }) : null;
  resizeObserver?.observe(canvas);
  const observer = typeof IntersectionObserver==='function' ? new IntersectionObserver(entries => {
    visible=entries.some(entry=>entry.isIntersecting);
    if(!visible) suspend(); else requestDraw();
  }, {threshold:0}) : null;
  observer?.observe(stage);
  canvas.addEventListener('webglcontextlost', event => {
    event.preventDefault(); lost=true; suspend(); fallback('Still view · 3D rendering paused');
  });
  canvas.addEventListener('webglcontextrestored',initialize);
  window.addEventListener('pagehide', event => { suspend(); if(!event.persisted) { disposed=true; observer?.disconnect(); resizeObserver?.disconnect(); } });
  window.addEventListener('pageshow', event => { if(event.persisted) { resize(); requestDraw(); } });
  initialize();
})();
