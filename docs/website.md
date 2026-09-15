# Website

GitHub Pages serves `docs/`. The homepage and five instrument pages share
`site.css`; `site.js` handles instrument selection, website accents, the native
video dialog and copy feedback. No build step or third-party JavaScript is needed.

The black-hole entrance remains isolated in `threshold.css` and `threshold.js`.
It uses a single animation clock and respects reduced motion. Its session marker
is optional; blocked storage does not prevent entrance. With JavaScript disabled,
the homepage exposes all instrument descriptions and bypasses the entrance.

Preview from the repository root:

```sh
python3 -m http.server 8765 --directory docs
node --check docs/site.js
node tests/test_site.cjs
node tests/test_threshold.cjs
```

The Node tests check controller behavior with DOM fixtures, not browser rendering.
Visual acceptance for the redesign was provided by the maintainer on the local
preview. Automated local browser inspection was blocked by the browser tool.

Check the actual browser after changes: entrance, instrument tabs with arrow keys,
all five detail pages, mobile overflow, accent buttons, video playback and Escape,
copy success/denial, and the operating system's reduced-motion setting.
