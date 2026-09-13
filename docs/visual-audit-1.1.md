# Tonantzintla visual audit — 2026-09-05

## Evidence and limits

This is a bounded review of the supplied desktop screenshots and local QML,
compared with current upstream documentation and component organization. Neither
other shell was installed or benchmarked. Serpantinum preview image downloads
failed, so no claim here is a pixel-level comparison of its 2.0 appearance.

Serpantinum's current README describes the migration from dotfiles to a shell and
separates compositor configuration from shell configuration. Its reusable component
directory contains dropdown, number-selector, switch, input, and button components.
The useful lesson for us is a coherent control family and explicit configuration
ownership, not copying its imagery.
[README](https://github.com/ilyamiro/serpantinum),
[reusable components](https://github.com/ilyamiro/serpantinum/tree/master/src/quickshell/reusables).

Caelestia explicitly describes a fluid, morphing shell. Its published Appearance
accessor groups rounding, spacing, padding, fonts, animation, and transparency;
the retrieved raw accessor may be an older indexed revision. This supports using
shared visual parameters, but does not prove current animation quality or cost.
[Project](https://github.com/caelestia-dots/shell),
[appearance accessor](https://raw.githubusercontent.com/caelestia-dots/shell/main/config/Appearance.qml).

## Independent surface findings

| Surface | Observed issue or risk | Recommended next change | Acceptance check |
| --- | --- | --- | --- |
| Aperture | Abstract glyphs hide destination; question mark is not our identity | Actual logo (implemented), then consistent hover labels and keyboard focus | Every icon names its action without opening it |
| Settings | Native white controls broke the palette; success messages expose long backup paths | Themed Niri page (implemented); move technical paths into expandable details | No native-style controls; full keyboard navigation |
| Calendar | Desktop text competed with chart labels; multiple animations can overlap | Keep solid backing and blobs, but give geometry one transition owner | Rapid CAL/HELIO/EARTH switching at small and large resolutions without clipped labels |
| Resonance | Previous ambience escaped rounded boundaries | Keep the existing rounded clip; verify art, gradient and controls share it | Bright artwork never paints beyond any corner |
| Parallax | The replacement grid discarded the signature orbit | Preserve orbit; improve selection/favorite/Apply feedback in place | Selection is obvious without replacing the orbit with cards |
| Notifications/System | Diamond opened duplicate telemetry under a Notifications heading | Remove that rail (implemented); keep actual notification history and System distinct | Notification icon opens alerts; System opens measurements |
| Typography/status | Screenshot shows FONTCONFIG OFFLINE despite visible fonts | Distinguish checking, missing tool, failed query, and fallback | No misleading offline label while discovery is pending |

These recommendations are our design judgments, not upstream feature claims.

## Priorities

1. One shared themed control family: selected, hovered, focused, disabled, pending,
   and failed states. Cursor choice buttons should eventually reuse it rather than
   remaining an inline special case.
2. One panel contract: solid backing, real rounded clipping, consistent content
   insets. Parallax's intentionally open orbit is the documented exception.
3. One animation clock per transition. Reduced motion must simplify geometry, not
   merely shorten several independent animations. Preserve expressive blobs.
4. Test screenshots at 1366×768, 1920×1080, and fractional scaling, using bright
   wallpaper, long titles, missing data and rapid switching. Compilation tests
   alone do not establish these visual properties.

Good later Niri additions: touchpad tap/natural scrolling, pointer acceleration,
and focus-following behavior. Add these only after extending the config helper's
nested-node editing and tests. Monitor modes and keybindings need a separate
rollback/confirmation design; a bad setting can make the desktop difficult to use.

Implemented in this pass: actual Aperture logo, removal of the diamond rail and its
settings, compatibility routing to System, hide-cursor-while-typing and idle-hide
delay. Niri options follow its [cursor documentation](https://niri-wm.github.io/niri/Configuration:-Miscellaneous.html#cursor).
