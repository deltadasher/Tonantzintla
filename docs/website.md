# Website

GitHub Pages serves the static `docs/` site from `main`, using the repository's
existing Pages build and deployment. No Node build, framework, analytics,
third-party JavaScript, or external font requests are required.

The homepage and five instrument pages share `site.css`. The real black-hole
mark, locally bundled typefaces, desktop captures and silent demo remain the
project's visual identity. The detail pages link to each instrument's source;
they describe one shell with five focused instruments, not separate runtimes.

`site.js` handles accessible instrument tabs (including arrows, Home and End),
direct panel links, every demo trigger, native modal cleanup and focus return,
clipboard success/denial feedback, and optional in-view decoration. The FAQ uses
native HTML disclosure elements and needs no JavaScript.

The homepage opens immediately. `gravity-scene.js` adds an optional WebGL2
material study: an asymmetric, ray-marched accretion stream derived from the
project's actual mark. This is an artistic browser interpretation, not a
simulation or a claim about the shell's own renderer. Drag or use focused arrow
keys to rotate, pause its motion or reset the view. Instrument selection gently
changes its material. Native controls and essential content remain stationary.

The renderer compiles and links its own GLSL shaders, caps its pixel budget,
and suspends animation offscreen, in hidden documents and on page departure.
Reduced motion draws a still view. Context loss, missing WebGL2 or a shader
failure restores the real SVG mark with a readable unavailable status. No FPS,
hardware-acceleration or benchmark claims are made. There is no entrance gate.
The retired threshold controller remains in source only for historical coverage.
Without JavaScript, the real mark, every instrument description, installation
commands and a direct recording link remain available; inactive controls hide.

Local stylesheet and controller URLs carry content-hash revisions so cached
assets cannot drift behind updated markup. The static validator checks these
revisions; refresh the query value whenever the referenced file changes.

The site includes canonical/social metadata, a six-page `sitemap.xml`, and a
project-path-aware `404.html`. Existing Google site verification is preserved.

Preview from the repository root:

```sh
python3 -m http.server 8765 --directory docs
node --check docs/site.js
node --check docs/gravity-scene.js
node --check docs/threshold.js
node tests/test_site.cjs
node tests/test_gravity_scene.cjs
node tests/test_threshold.cjs
python3 tests/test_static_site.py
```

The static validator checks structure, local links, source paths, image sizes,
metadata, and publishing artifacts. DOM-fixture tests establish controller
behavior, not browser rendering. Check
an actual browser before release: 360px/mobile and desktop widths, horizontal
overflow, blocked storage, no-JavaScript content, keyboard tabs and focus,
all five detail pages, modal playback/close/Escape/repeated opens, copy fallback,
FAQ disclosures, and operating-system reduced motion.

Publishing is complete only after the expected commit is on the remote, that
commit's Pages build/deployment succeeds, and the live site serves the new
content and assets. Do not treat a successful push as a completed deployment.
