# How to build Tonantzintla

Updated: 2026-09-05. Audience: coding and design agents working on this repository.

## 1. The product, in one sentence

An observatory you operate: astronomy gives the interface its identity, while
everyday controls remain legible, predictable and useful.

It is not a generic dashboard with space nouns pasted onto cards. It is also not
an animation demo where operating the desktop comes second. Orbits, imperfect
silhouettes and flowing surfaces are intentional. Keep the strange shapes; make
their behavior unsurprising.

The public command is `blackhole`. The checkout may still be called `astralith`;
that directory name does not identify the installed version or running instance.

## 2. Decisions the user has already made

Treat these as constraints unless the user explicitly changes direction:

| Area | Preserve | Do not repeat |
| --- | --- | --- |
| Instrument surfaces | Solid dark backing, translucent controls | Desktop text visible through Calendar or ordinary settings panels |
| Motion | Blobs, expanding surfaces, orbital character | Removing effects as a shortcut to fixing transitions |
| Parallax | Orbiting wallpaper presentation | Replacing it with a giant rectangular preview/grid |
| Resonance | Artwork and ambience inside a genuinely rounded boundary | Assuming Rectangle.clip makes rounded corners |
| Branding | Existing WabiSabiBlackHole component | Invented crescent glyphs, generic rings or a question mark as the logo |
| Navigation | One recognizable destination per action | Chronos, duplicate telemetry sidepanel, misleading Notifications heading |
| Settings | Real integration, clear status, consistent theme | Native white controls, inert toggles, always-success feedback |
| Portability | Discover the user's apps, tools, devices and location | Developer-machine app lists, home paths, geography or preferred applications |
| Platform | Working Niri integration and Obarun compatibility | Assuming systemd exists everywhere or importing Hyprland-specific behavior into Niri |

### Visual rules

- Use Theme tokens for typography, color, spacing and states. Extend a shared
  component when several surfaces need the same behavior.
- Keep labels and hit targets stable during decorative movement. Deformation can
  affect a surface silhouette without making a button harder to hit.
- Active, hover, keyboard focus, disabled, pending and failed are different states.
- Keep essential text readable independently of artwork and wallpaper colors.
- Use ordinary language for errors. Put paths and diagnostics under Details.
- Avoid meaningless uppercase telemetry: name the data, unit and action honestly.
- Reduced motion must simplify movement. It must not disconnect features or leave
  a half-deployed layout.

## 3. Architecture and ownership

Read architecture.md for the full map. Important editing boundaries:

- `src/quickshell/shell.qml`: composition and lifetime, not feature implementation.
- `Settings.qml`: persisted user preferences, aliases and migrations.
- `Theme.qml`: shared visual parameters.
- `ShellState.qml`: transient navigation, visibility and routing.
- `components/SurfaceTransition.qml`: mounted content and transition coordination.
- `modules/ephemeris/EphemerisSurface.qml`: the layer-shell host and widget loader.
- `services/`: shared external state; one acquisition path per resource.
- `src/libexec/`: bounded system integrations and data helpers.
- `bin/blackhole`: the public control entry point.
- `install/`: transactional installation; do not create a competing installer.

Separate four questions: what code is in the checkout, what is installed, what
process is running, and what the user can actually see. A successful commit says
nothing about the other three. A restart does not copy local source changes.

Keep user data in XDG directories. Resolve tools and resources rather than storing
the developer's absolute paths. Preserve Niri config when installation uses
`--niri keep`; runtime-critical behavior must not depend solely on template edits.

### Security boundary: Umbra

`umbra-lock.qml` owns the real Wayland session-lock surfaces. Preview is not a lock.
The main shell's IdleLock/IdleWatcher starts an owned swayidle process after settings
load and invokes `blackhole lock`; the default idle timeout is five minutes.
Existing external idle processes are not killed. Compositor inhibitors can delay
inactivity events. Watcher startup does not prove that lock acquisition or PAM works.

The current fake-process test verifies command construction and start/stop behavior.
It does not test authentication, monitors, idle inhibition or suspend readiness.
Do not claim those are complete. Do not add display power-off or suspend to an
unverified security path and describe the result as secure.

## 4. Upstream research: evidence, not imitation

The following observations were read from public source on 2026-09-05. Links target
moving branches, not pinned release snapshots. Recheck them before copying a design
assumption into implementation. Neither upstream shell was installed or benchmarked.
Preview downloads and some Serpantinum reusable-component source requests failed.
No pixel-level or comparative performance claim is justified by this research.

### Caelestia: joined surfaces and input ownership

**Verified:** ContentWindow uses a shared BlobGroup with BlobRect/BlobInvertedRect
shapes. Panel backgrounds provide deformation matrices to content. The window also
coordinates input regions, fullscreen behavior and Hyprland-specific focus grabbing.
This is more than several rounded rectangles animating independently.
[Source: ContentWindow.qml](https://github.com/caelestia-dots/shell/blob/main/modules/drawers/ContentWindow.qml).

**Our decision:** borrow coordinated geometry, not the entire Hyprland host. Build
the smallest Niri-compatible solution that keeps visible shapes, clipping and input
regions synchronized. Do not add a renderer dependency without considering packaging,
fallback behavior and measured cost.

**Important current gap:** TonantzintlaMorphBackdrop.qml presently interpolates a
rounded Rectangle from a source capsule to a panel. Restoring its loader restores
that expansion, not Caelestia-style joined blob fields. Calendar's telemetry
metaball shader is a separate effect. Agents must not conflate the two.

### Caelestia: requested state versus displayed state

**Verified:** AppList distinguishes requested search mode from displayed mode,
changes content during an outgoing/incoming transition, and uses shared animation
and layout tokens. Its model-change handler resets selection to the first result.
[Source: AppList.qml](https://github.com/caelestia-dots/shell/blob/main/modules/launcher/AppList.qml).

**Our decision:** borrow transition sequencing, but preserve selection by stable
identity when it still exists. Never move the highlighted target merely because a
background result refreshed. Coalesce rapid requests; close must cancel entrance.

### Caelestia: gestures and shortcut semantics

**Verified:** Interactions contains configurable hover/drag activation and distinct
shortcut-active state. Pointer departure and fullscreen state affect dismissal.
[Source: Interactions.qml](https://github.com/caelestia-dots/shell/blob/main/modules/drawers/Interactions.qml).

**Our decision:** default to explicit click/keyboard opening; hover explains the
action. Any edge gestures are opt-in. Keyboard-opened surfaces should not vanish
because the pointer happens to be elsewhere. Do not copy hidden trigger zones
without clear discovery and a way to disable them.

### Serpantinum: media presentation and lifecycle

**Verified:** MusicPopup supports manual player selection, processes bass/kick data,
stages artwork/text/control entrances, and registers/unregisters a Cava consumer as
visibility changes. Its seek handling tracks dragging/pending state. Some decorative
animations in the retrieved file are configured as continuously running; this alone
does not establish their actual offscreen cost.
[Source: MusicPopup.qml](https://github.com/ilyamiro/serpantinum/blob/master/src/quickshell/media/MusicPopup.qml).

**Our decision:** borrow explicit player ownership, seek protection and consumer
lifecycle. Keep our orbital artwork and Pitcher. Essential playback controls should
not wait for a long entrance. Animate surrounding decoration, not the target under
the pointer. Unknown duration is not proof of a live stream: show an unavailable
duration rather than inventing either zero length or LIVE metadata.

### Serpantinum: reusable controls and platform separation

**Verified:** its reusable directory lists dropdowns, number selectors, inputs,
switches and buttons. Its README describes the migration from dotfiles to a shell
and separates compositor configuration responsibilities. Directory presence does
not prove accessibility or runtime quality.
[Reusable directory](https://github.com/ilyamiro/serpantinum/tree/master/src/quickshell/reusables),
[README](https://github.com/ilyamiro/serpantinum).

**Our decision:** one themed control family and an explicit compositor-integration
boundary. Do not reproduce our recent inline cursor-control one-off across modules.
Extract it when adding the next consumer. Review upstream licenses before reusing
code; these observations authorize neither copying nor rebranding their assets.

## 5. What to build next, and what counts as done

These are recommendations, not claims that implementation is complete.

1. **Unified morphing:** preserve solid backing and coherent motion under repeated
   open/switch/close. Verify corners, input regions and fullscreen behavior. A
   screenshot of the final frame cannot prove a transition works.
2. **Shared control states:** themed controls, visible keyboard focus and readable
   tooltips everywhere. Test Tab, arrows where applicable, Enter, Space and Escape.
3. **Resonance:** unambiguous selected player, stable seeking, all controls usable
   with long titles, missing artwork and unavailable duration. Keep rounded clipping.
4. **Parallax:** persistent applied marker, preview without application, stable
   favorites and search selection. Preserve orbit. Confirm backend success before
   displaying Applied; a stored requested path is insufficient.
5. **Niri settings:** unsaved/applied/error states and expandable diagnostics first.
   Undo requires a validated, concurrency-aware transaction; a backup filename
   alone is not an Undo feature. Input and monitor settings need additional parsing
   and recovery tests before exposure.

Current cursor helper rejects some complicated/included configs instead of risking
an unsafe rewrite. Keep that limitation visible. Do not replace the guard with
unbounded regex edits to make an unsupported case appear successful.

## 6. Required workflow for an agent

1. Read the current request and constraints above. Inspect git status and relevant
   source before editing. Do not mistake old notes for current facts.
2. Trace the entire path: input → state → UI → helper/backend → confirmation.
3. State a bounded plan, especially for a visual change. Repair a regression without
   silently changing unrelated transparency, layout or daemon ownership.
4. Implement one coherent change with existing primitives. Preserve dirty work.
5. Run relevant tests and inspect the actual result when the environment permits.
6. Report source versus installed state, tests passed/skipped, and remaining host
   verification. Never imply an install, restart, commit or push happened when it did not.

Useful checks from the repository root:

```bash
git diff --check
python3 -m unittest discover -s tests -q
bash tests/test_cli.sh
./tools/check --partial
```

For installer changes, run the Rust tests through tools/check or
`cargo test --locked --manifest-path install/Cargo.toml`; report dependency/network
blocks accurately. Prefer Qt 6 tooling, not a Qt 5 executable earlier on PATH.

Visual acceptance needs small/large resolutions, fractional scaling, bright and
dark wallpaper, long labels, missing integrations and rapid switching. Secure-lock
acceptance needs explicit host tests: manual lock/unlock, idle expiry, cancellation
by activity, inhibitor behavior and multi-monitor coverage. Suspend testing is a
separate gate. Do not initiate disruptive tests without user consent.

## 7. Handoff checklist

- What user-visible behavior changed?
- What existing behavior was deliberately preserved?
- Which source files and external state were changed?
- Which tests ran, and what do those tests actually prove?
- What is unverified, unsupported, uncommitted or not yet installed?
- What is the smallest next action the user needs to take?

When uncertain, choose a truthful limitation and a reversible implementation over
a convincing-looking success message.
