# Theme identities

Open **Settings → Appearance → Logo**.

Choose one of fourteen approved SVGs, or select **Follow theme color**. Automatic selection prioritizes your exact action color, then your chosen Matugen seed, then the wallpaper's source color or the selected accent preset. Generated lighter primary colors are not used to override an explicit choice.

Choosing a logo does not change your palette. **Use [name] color** separately applies its exact color and generates supporting colors through Matugen. Logos always retain their original SVG colors. Wabi Sabi is the default and keeps its original amber stream and black horizon.

**Color mode** is always visible above Logo, Colors and Style. Light and Dark stay selected when you change logos or styles, and also apply to the lock and login screens. Auto follows your theme color (or your separate button color), not the logo. Leaf keeps its dark lock background in Auto; you can still choose Light explicitly.

Choosing a logo changes the bar icon and lock artwork only. “Use [name] color” is a separate action.

**Preview lock** opens Umbra's existing safe preview. Each selected identity has a complete, contained native vector illustration with restrained motion. Wide screens reserve the left side for controls; tall screens place the illustration above the clock and password entry. Ink uses an ink splatter, Cloud uses a shaded cloud, and the other scenes use simple subjects without loose decorative marks. Scene colors adapt to Light or Dark while bar logos retain their approved colors. Wabi Sabi keeps the original amber SVG and black horizon. The illustrations draw on size/theme changes and animate cached items; they stop moving when hidden or when motion is disabled.

**Preview login screen** opens an SDDM test window. The login screen uses a system-wide snapshot, so it is updated separately from personal shell settings:

```bash
blackhole greeter install sddm   # update the installed snapshot
blackhole greeter activate sddm  # also select it for the next login screen
```

These commands request administrator authentication through the existing installer. They never restart SDDM or end the current session. Selecting a different logo later updates session locks immediately; run install again to update the login snapshot. Other existing display-manager adapters retain their previous behavior; the illustrated login theme is for SDDM.

The original twelve replacement marks came from the approved V3 SVG archive. Snowflake and Wabi Sabi are the approved unchanged originals. Their hashes are recorded in `ThemeIdentities.js`; the shared registry also supplies the greeter exporter. Authentication, password storage, PAM, session selection and Wayland lock ownership are unchanged.
