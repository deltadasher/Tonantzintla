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

The black-hole entrance is isolated in `threshold.css` and `threshold.js`.
It starts only when JavaScript is working, uses one animation clock, accepts
Escape, respects reduced motion, and bypasses itself for direct content links.
Its session marker is optional; blocked storage does not prevent entrance.
Without JavaScript, content and installation commands remain visible, all five
instrument descriptions are exposed, and the recording has a direct link.

The site includes canonical/social metadata, a six-page `sitemap.xml`, and a
project-path-aware `404.html`. Existing Google site verification is preserved.

Preview from the repository root:

```sh
python3 -m http.server 8765 --directory docs
node --check docs/site.js
node --check docs/threshold.js
node tests/test_site.cjs
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
