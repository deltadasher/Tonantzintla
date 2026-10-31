# Theme identities

Open **Settings → Appearance → Theme studio → Identity**.

Choose one of fourteen approved SVGs, or select **Follow theme color**. Automatic selection prioritizes your exact action color, then your chosen Matugen seed, then the wallpaper's source color or the selected accent preset. Generated lighter primary colors are not used to override an explicit choice.

Choosing a logo does not change your palette. **Use [name] color** separately applies its exact color and generates supporting colors through Matugen. Logos always retain their original SVG colors. Wabi Sabi is the default and keeps its original amber stream and black horizon.

With Automatic appearance, manually selected dark marks (ruby, fire, leaf, night sky, cloud and ink) use light surfaces. Other marks use dark surfaces. When following the theme color, dark chosen colors get light surfaces and pale chosen colors get dark surfaces. Explicit Light or Dark controls desktop surfaces. Leaf always uses a dark botanical scene on the lock and login screens. Its lock illustration uses a natural plant without the standalone leaf emblem; its bar and picker logo remain unchanged. Logos retain their exact SVG colors, with transparent backgrounds and sizing fitted to their visible artwork.

**Preview lock** opens Umbra's existing safe preview. Each selected identity has a complete, contained native vector illustration with restrained motion. Wide screens reserve the left side for controls; tall screens place the illustration above the clock and password entry. Wabi Sabi uses a simplified accretion illustration with the original amber SVG and black horizon. The illustrations draw on size/theme changes and animate cached items; they stop moving when hidden or when motion is disabled.

**Preview login screen** opens an SDDM test window. The login screen uses a system-wide snapshot, so it is updated separately from personal shell settings:

```bash
blackhole greeter install sddm   # update the installed snapshot
blackhole greeter activate sddm  # also select it for the next login screen
```

These commands request administrator authentication through the existing installer. They never restart SDDM or end the current session. Selecting a different logo later updates session locks immediately; run install again to update the login snapshot. Other existing display-manager adapters retain their previous behavior; the illustrated login theme is for SDDM.

The original twelve replacement marks came from the approved V3 SVG archive. Snowflake and Wabi Sabi are the approved unchanged originals. Their hashes are recorded in `ThemeIdentities.js`; the shared registry also supplies the greeter exporter. Authentication, password storage, PAM, session selection and Wayland lock ownership are unchanged.
