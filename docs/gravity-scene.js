/* SPDX-License-Identifier: GPL-3.0-or-later
 * Tonantzintla's browser-native observatory study.
 * Bent-light rays through a thin emissive disk, not a solid sculpted torus.
 * Physically inspired; this is an illustration, not a precision simulation.
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
  const float HORIZON = .72;
  mat2 turn(float a) { float s=sin(a),c=cos(a); return mat2(c,-s,s,c); }
  float hash(vec2 p) {
    p=fract(p*vec2(123.34,456.21)); p+=dot(p,p+45.32);
    return fract(p.x*p.y);
  }
  float noise(vec2 q) {
    vec2 i=floor(q),f=fract(q); f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),
      mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);
  }
  float gas(vec2 q) {
    float value=0.,weight=.55;
    for(int j=0;j<4;j++) {
      value+=weight*noise(q);
      q=mat2(1.6,1.2,-1.2,1.6)*q+vec2(4.7,9.2); weight*=.5;
    }
    return value;
  }
  vec3 acceleration(vec3 p,float angularMomentum) {
    float r=length(p);
    return -1.5*HORIZON*angularMomentum*p/max(pow(r,5.),.001);
  }
  // Curved null-ray approximation in a nonrotating Schwarzschild field.
  // Gas occupies a flat, zero-thickness equatorial disk. Its raised image is
  // caused by bent light, never by folding or extruding the disk geometry.
  vec3 trace(vec2 screen) {
    vec3 ro=vec3(0.,2.32,12.);
    ro.yz=turn(rotation.y)*ro.yz; ro.xz=turn(rotation.x)*ro.xz;
    vec3 fw=normalize(-ro);
    vec3 right=normalize(cross(fw,vec3(0.,1.,0.))),up=cross(right,fw);
    vec3 velocity=normalize(fw*1.35+right*screen.x+up*screen.y);
    vec3 p=ro, radiance=vec3(0.);
    float angularMomentum=dot(cross(p,velocity),cross(p,velocity));
    float opacity=0.;
    for(int i=0;i<192;i++) {
      float r=length(p),step=.045+.048*r;
      vec3 acc=acceleration(p,angularMomentum);
      vec3 next=p+velocity*step+.5*acc*step*step;
      vec3 nextVelocity=velocity+.5*(acc+acceleration(next,angularMomentum))*step;
      if(p.y*next.y<0.) {
        float fraction=clamp(p.y/(p.y-next.y),0.,1.);
        vec3 hit=mix(p,next,fraction);
        float radius=length(hit.xz);
        if(radius>2.15 && radius<5.4) {
          float angle=atan(hit.z,hit.x);
          float edge=smoothstep(2.15,2.42,radius)*(1.-smoothstep(3.4,5.4,radius));
          float heat=pow(2.5/max(radius,2.15),2.7);
          float shear=angle+radius*.58-time*.035/pow(radius,1.5);
          vec2 q=vec2(cos(shear),sin(shear))*radius*1.8;
          float cloud=.38+.9*gas(q);
          float beaming=pow(1.+.38*(-hit.x/radius),3.);
          vec3 emission=mix(vec3(1.,.26,.055),vec3(1.,.9,.68),heat*.8);
          float power=heat*edge*cloud*beaming*1.3;
          radiance+=emission*power*(1.-opacity);
          // Both light and optical depth fade smoothly at the disk edges.
          opacity+=(1.-opacity)*.88*edge;
        }
      }
      p=next; velocity=nextVelocity;
      float distance=length(p);
      if(distance<HORIZON || distance>15.5 || opacity>.99) break;
    }
    return radiance;
  }
  void main() {
    vec2 screen=(uv-.5)*vec2(resolution.x/resolution.y,1.);
    // Two fixed subpixel rays soften the very narrow photon image without
    // flickering temporal jitter. This remains a bounded, dependency-free draw.
    vec2 pixel=vec2(.25)/resolution.y;
    vec3 radiance=.5*(trace(screen-pixel)+trace(screen+pixel));
    vec3 background=vec3(.0431,.0431,.0510);
    vec3 result=max(background,1.-exp(-radiance*.85));
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
  let entered = !document.getElementById('threshold') || document.getElementById('threshold').hidden;
  const canAnimate = () => entered && !disposed && !lost && visible && !document.hidden && !frozen && !reduced.matches;
  function setStatus(text) { if (status) status.textContent = text; }
  function updateControls() {
    if (motionButton) {
      motionButton.setAttribute('aria-pressed', String(frozen));
      motionButton.textContent = !program || lost ? 'Still view' : reduced.matches ? 'Reduced motion' : frozen ? 'Resume motion' : 'Pause motion';
      motionButton.disabled = reduced.matches || lost || !program;
    }
    if (resetButton) resetButton.disabled = lost || !program;
  }
  function releaseResources() {
    if (gl && !gl.isContextLost?.()) {
      if (program) gl.deleteProgram(program);
      if (buffer) gl.deleteBuffer(buffer);
    }
    program=null; buffer=null;
  }
  function fallback(message) {
    releaseResources();
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
    if (disposed) return;
    releaseResources();
    let vs, fs;
    try {
      const attributes = { alpha: false, antialias: false, depth: false, stencil: false, powerPreference: 'low-power', preserveDrawingBuffer: false };
      gl = canvas.getContext('webgl2', attributes);
      const modern = Boolean(gl);
      if (!gl) gl = canvas.getContext('webgl', attributes);
      if (!gl) { fallback(); return; }
      // The same geometry also works on browsers with WebGL 1 only.
      const vsSource = modern ? vertexSource : vertexSource.replace('#version 300 es','').replace('in vec2 position','attribute vec2 position').replace('out vec2 uv','varying vec2 uv');
      const fsSource = modern ? fragmentSource : fragmentSource.replace('#version 300 es','').replace('in vec2 uv','varying vec2 uv').replace('out vec4 color;','').replace(/\bcolor\b/g,'gl_FragColor');
      vs = compile(gl.VERTEX_SHADER, vsSource);
      fs = compile(gl.FRAGMENT_SHADER, fsSource);
      program = gl.createProgram();
      gl.attachShader(program, vs); gl.attachShader(program, fs); gl.linkProgram(program);
      gl.deleteShader(vs); gl.deleteShader(fs); vs=null; fs=null;
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
      if (vs) gl.deleteShader(vs); if (fs) gl.deleteShader(fs);
      console.warn('Tonantzintla: using the still black-hole view.', error);
      fallback();
    }
  }
  function resize() {
    if (!gl || !program || lost) return;
    const rect = canvas.getBoundingClientRect();
    // The curved-ray composition is capped by both DPR and total pixel area.
    const compact = rect.width < 600;
    let ratio = Math.min(window.devicePixelRatio || 1, compact ? 1.35 : 1.65);
    const pixels = Math.max(1, rect.width * rect.height);
    ratio = Math.min(ratio, Math.sqrt((compact ? 180000 : 360000) / pixels));
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
  document.addEventListener('tonantzintla:entered', () => { entered=true; resize(); requestDraw(); });
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
  window.addEventListener('pagehide', event => { suspend(); if(!event.persisted) { disposed=true; releaseResources(); observer?.disconnect(); resizeObserver?.disconnect(); } });
  window.addEventListener('pageshow', event => { if(event.persisted) { resize(); requestDraw(); } });
  initialize();
})();
