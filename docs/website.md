# Website

GitHub Pages serves the static `docs/` site from `main`, using the repository's
existing Pages build and deployment. No Node build, framework, analytics,
third-party JavaScript, or external font requests are required.

The homepage and five instrument pages share `site.css`. The real black-hole
mark, locally bundled typefaces, desktop captures and silent demo remain the
project's visual identity. The detail pages link to each instrument's source;
they describe one shell with five focused instruments, not separate runtimes.

Text is set in Instrument Sans, a 29 KB Latin WOFF2 subset with a variable
weight axis (`fonts/instrument-sans-OFL.txt`). Labels, figures and commands use a
13 KB subset of JetBrains Mono, the shell's own type
(`fonts/jetbrains-mono-OFL.txt`). Avayx remains the wordmark. The homepage Principles section
makes factual claims: the 450 MB budget comes from `docs/memory-budget.md`, the
network services from `src/libexec`, and the four test suites from `tools/check`.
Update the copy when any of those change.

`site.js` handles accessible instrument tabs (including arrows, Home and End),
direct panel links, every demo trigger, native modal cleanup and focus return,
clipboard success/denial feedback, and optional in-view decoration. The FAQ uses
native HTML disclosure elements and needs no JavaScript.

The original black-hole mark arrival and unfolding opening are restored. Click
the mark to enter; keyboard focus shows the same glow as hover rather than a
ring. The visible Skip intro button and Escape dismiss it immediately, including while it is arriving or unfolding. Reduced motion,
session revisits and direct fragment links bypass it. Underlying content is only
inert while the opening is shown; dismissal restores its prior state and returns
focus from either intro button to the stable home link. Tab is never intercepted.
Blocked storage does not prevent entry, and no JavaScript shows the site directly.

The opening controller and its integration have regression coverage. The hero
shows the real desktop recording; there is no WebGL scene. Without JavaScript,
the real mark, every instrument description, installation commands and a direct
recording link remain available; inactive controls hide.

Local stylesheet and controller URLs carry content-hash revisions so cached
assets cannot drift behind updated markup. The static validator checks these
revisions; refresh the query value whenever the referenced file changes.

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
