(() => {
  const threshold = document.querySelector('#threshold');
  const enter = threshold.querySelector('.threshold-hole');
  const svg = threshold.querySelector('.threshold-peel');
  const halves = ['top', 'bottom'].map(side => ({
    sheet: svg.querySelector(`.threshold-sheet.${side}`),
    fold: svg.querySelector(`.threshold-fold.${side}`),
    edge: svg.querySelector(`.threshold-edge.${side}`),
  }));
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const key = 'tonantzintla-entered';
  const clamp = value => Math.max(0, Math.min(1, value));
  const smooth = value => { const t = clamp(value); return t * t * (3 - 2 * t); };
  const content = [...document.querySelectorAll('body > header, body > main, body > footer')];
  let started = null;
  let frame = 0;
  let width, height, radius;
  const duration = 1850;
  const cutEnd = 0.56;

  // Storage can be blocked; entrance must still work without it.
  try { threshold.hidden = sessionStorage.getItem(key) === '1'; } catch {}
  if (threshold.hidden) return;
  const previousOverflow = document.documentElement.style.overflow;
  document.documentElement.style.overflow = 'hidden';
  content.forEach(element => { element.inert = true; });

  const finish = () => {
    cancelAnimationFrame(frame);
    threshold.hidden = true;
    document.documentElement.style.overflow = previousOverflow;
    content.forEach(element => { element.inert = false; });
    try { sessionStorage.setItem(key, '1'); } catch {}
    if (document.activeElement === enter) {
      document.querySelector('.site-tab')?.focus({ preventScroll: true });
    }
    window.removeEventListener('resize', resize);
    motion.removeEventListener('change', onMotionChange);
  };

  function resize() {
    width = threshold.clientWidth;
    height = threshold.clientHeight;
    // Covers every corner and carries the entire mark beyond the right edge.
    radius = Math.hypot(width / 2, height / 2) + enter.offsetWidth;
    svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
  }

  function draw(progress) {
    const travel = smooth(progress / cutEnd);
    const peel = smooth((progress - cutEnd) / (1 - cutEnd));
    const angle = Math.PI * peel;
    const distance = radius * travel;
    const cx = width / 2, cy = height / 2;
    const bow = height * 0.18 * travel * (1 - peel);
    const curl = Math.min(42, height * 0.055) * travel * (1 - peel);
    const x = cx + Math.cos(angle) * distance;
    const outerX = cx + Math.cos(angle) * radius;
    const left = cx - radius;

    halves.forEach(({ sheet, fold, edge }, index) => {
      const sign = index === 0 ? -1 : 1;
      const y = cy + sign * Math.sin(angle) * distance;
      const outerY = cy + sign * Math.sin(angle) * radius;
      // A shared cubic edge is both the cut and the lip of the folded sheet.
      const curve = amount => {
        const nx = -Math.sin(angle) * amount;
        const ny = sign * Math.cos(angle) * amount;
        return [cx + (x - cx) * 0.3 + nx, cy + (y - cy) * 0.3 + ny,
                cx + (x - cx) * 0.74 + nx, cy + (y - cy) * 0.74 + ny];
      };
      const [a, b, c, d] = curve(bow);
      const [e, f, g, h] = curve(bow + curl);
      const boundary = `M ${cx} ${cy} C ${a} ${b} ${c} ${d} ${x} ${y}`;
      sheet.setAttribute('d', `${boundary} L ${outerX} ${outerY} A ${radius} ${radius} 0 0 ${index} ${left} ${cy} Z`);
      fold.setAttribute('d', `${boundary} C ${g} ${h} ${e} ${f} ${cx} ${cy} Z`);
      edge.setAttribute('d', boundary);
      edge.style.opacity = String(0.65 * smooth(travel * 5) * (1 - smooth((peel - 0.8) / 0.2)));
    });
    enter.style.transform = `translate3d(${distance}px,0,0) rotate(${travel * 540}deg) scale(${1 - travel * 0.18})`;
  }

  function tick(now) {
    if (started === null) started = now;
    const progress = clamp((now - started) / duration);
    draw(progress);
    if (progress < 1) frame = requestAnimationFrame(tick);
    else finish();
  }
  function onMotionChange() { if (motion.matches) finish(); }
  function dismiss() {
    if (threshold.classList.contains('departing')) return;
    if (motion.matches) { finish(); return; }
    // Finish the brief arrival first rather than replacing an in-flight transform.
    const arrival = enter.getAnimations().find(animation => animation.playState === 'running');
    if (arrival) {
      enter.disabled = true;
      arrival.finished.then(() => { enter.disabled = false; dismiss(); }).catch(finish);
      return;
    }
    resize();
    draw(0);
    threshold.classList.add('departing');
    frame = requestAnimationFrame(tick);
  }
  enter.addEventListener('click', dismiss);
  window.addEventListener('resize', resize);
  motion.addEventListener('change', onMotionChange);
})();
