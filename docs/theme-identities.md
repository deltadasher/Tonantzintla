# Theme identities

Open **Settings → Appearance → Logo**.

Choose one of fourteen approved SVGs, or select **Follow theme color**. Automatic selection prioritizes your exact action color, then your chosen Matugen seed, then the wallpaper's source color or the selected accent preset. Generated lighter primary colors are not used to override an explicit choice.

Choosing a logo does not change your palette. **Use [name] color** separately applies its exact color and generates supporting colors through Matugen. Logos always retain their original SVG colors. Wabi Sabi is the default and keeps its original amber stream and black horizon.

**Color mode** is always visible above Logo, Colors and Style. Light and Dark stay selected when you change logos or styles, and also apply to the lock and login screens. Auto follows your theme color (or your separate button color), not the logo. Leaf keeps its dark lock background in Auto; you can still choose Light explicitly.

Choosing a logo changes the bar icon and the lock and login screens only (artwork, typefaces and controls). “Use [name] color” is a separate action.

**Preview lock** opens Umbra's existing safe preview. Every lock scene is built around the selected logo itself: the approved SVG, unchanged, set into a small world drawn in the same language as the marks. Scenery uses flat fills in the logo's own hue (its second color where the mark has one), softly rounded corners, chunky shapes and no interior detail lines. The ruby hovers over its geode, the flame stands on a campfire, the snowflake turns in front of a stand of firs, the moon is seen through an arched window, and the night sky's crescent sits in the core of a slowly turning galaxy watched by an observatory dome. Where a logo would disappear into its background (Ink, Night sky and Cloud in Dark; Snowflake and Moon in Light), the scene supplies a natural backing: the paper sheet, galaxy core, pale arcs, firs or night window. Scene colors adapt to Light or Dark; the logos keep their approved colors. Wide screens reserve the left side for controls; tall screens place the illustration above the clock and password entry.

Scenery is painted once into cached layers and then only moved by one shared slow clock (a 120-second loop), so motion never repaints. It stops when the lock is hidden or motion is disabled, and settles into a still composition.

Each logo also has its own voice on the lock and login screens, defined in `components/identity/LockStyles.js`:

- **Typefaces** for the clock, date and labels, with their own date format, casing and spacing. Wabi Sabi keeps JetBrains Mono. The others use Palatino, Rubik, condensed Noto Sans, Bookman, Noto Serif italics, Hack, Adwaita Sans, Avant Garde, Iosevka, thin condensed Noto Sans, Century Schoolbook, Helvetica and Zapf Chancery (their URW and open equivalents).
- **A password line**: each typed character adds one glyph; the password is never drawn.
- **Buttons in the logo's silhouette** (a ruby shard, a shell, a flame, a cloud…), with drawn icons, placed differently per logo.
- **On the login screen**, its own way of offering user and session (captions, chips, a "Sign in as … on …" sentence, a stacked list or monospace brackets), and its own place for the sleep, restart and shut-down buttons.

The faces come from the "Identity lock typography" group of `blackhole install` (`gsfonts`, `noto-fonts`, `ttf-rubik-vf`, `adwaita-fonts`, `ttf-hack`). A missing face falls back to the system font; the layout and controls are unaffected.

**Preview login screen** opens an SDDM test window. The login screen uses a system-wide snapshot, so it is updated separately from personal shell settings:

```bash
blackhole greeter install sddm   # update the installed snapshot
blackhole greeter activate sddm  # also select it for the next login screen
```

These commands request administrator authentication through the existing installer. They never restart SDDM or end the current session. Selecting a different logo later updates session locks immediately; run install again to update the login snapshot. Other existing display-manager adapters retain their previous behavior; the illustrated login theme is for SDDM.

The original twelve replacement marks came from the approved V3 SVG archive. Snowflake and Wabi Sabi are the approved unchanged originals. Their hashes are recorded in `ThemeIdentities.js`; the shared registry also supplies the greeter exporter. Authentication, password storage, PAM, session selection and Wayland lock ownership are unchanged.
