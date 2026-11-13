# Parallax live wallpapers — November 11, 2026

Parallax can apply a live wallpaper: a scene the shell draws itself on the
background layer. There is no web engine and no helper process. A web view was
tried first and rejected: Quickshell 0.3.1 does not recognise the WebEngine pragma
and aborts when QtWebEngine is imported.

## What ships

| Scene | Source | Pointer |
| --- | --- | --- |
| Snowfall | `components/live/SnowScene.qml` (Qt Quick Particles) | Move to part the flakes, click for a gust |
| Life | `components/live/LifeScene.qml` | Move to seed cells, click for a burst |
| Flow field | `components/live/FlowScene.qml` | The pointer is a whirlpool, click scatters |
| System monitor | `components/live/ProcmonScene.qml` | None |
| Deep field | `components/live/DeepFieldScene.qml` | The view leans toward the pointer, click for a meteor |
| Constellations | `components/live/ConstellationScene.qml` | The pointer links to nearby stars, click pushes them apart |
| Aurora | `components/live/AuroraScene.qml` | Curtains lift toward the pointer, click for a surge |
| Orrery | `components/live/OrreryScene.qml` | The system leans toward the pointer, click launches a comet |

Scenes take their colors from Theme, so they follow the active palette.

## How it fits

- `components/LiveScenes.js` is the catalog: id, name, component and integer
  slider settings. `tests/test_live_scenes.cjs` checks it against the files.
- Each scene is an ordinary library entry of kind `live` whose `path` is its
  bundled still in `src/assets/wallpapers/live/`. The orbit, the palette and the
  optics use that still exactly as they use any image. `Settings.liveWallpaper`
  names the scene and `Settings.liveWallpaperProps` holds changed settings.
- `shell.qml` supplies the catalog to `Environment.liveWallpapers` and creates one
  `LiveWallpaper` window per selected output while the kind is `live`.
  `Environment` itself imports nothing from `components/`.
- Applying a live wallpaper stops a video that Tonantzintla started
  (`wallpaper-apply stop-video`). Applying any still or video changes the kind and
  the live windows unload.
- In Parallax, live wallpapers orbit with everything else and have a Live filter.
  When one is centered, the Options panel leads with its sliders and a Reset.
- Reduced or instant motion holds a scene on a still frame.

## Web wallpapers through undertow

undertow is a separate project: a daemon that draws web pages as wallpapers with
its own web engine, and installs them from GitHub. It is optional and is not
bundled or installed by Tonantzintla. When `undertow` is on PATH, Parallax is its
interface:

- `services/Undertow.qml` looks for the command once, reads the library with
  `undertow list --json` when Parallax opens and after each action, and never polls.
- Web wallpapers orbit as kind `web` with a Web filter. Applying one runs
  `undertow set <id> --headless`, so no tray icon or picker of undertow's appears.
  The kind becomes `web` only after that command succeeds. `wallpaperPath` keeps
  the last image, so colors and optics stay on it.
- With one centered and running, Options shows its slider and switch settings
  and passes changes to `undertow prop`. Its color, list and text settings are not
  shown. "Add from GitHub" runs `undertow add` and reports the result.
- Applying any other wallpaper releases it: undertow is quit if this shell
  started it, and only paused if the user had started it themselves.
- After a restart, the web wallpaper in use is started again on the first listing.
- Without undertow, Web entries do not exist and the Web filter explains why.

`shell.qml` passes the entries to `Environment.webWallpapers` and answers
`Environment.webWallpaperRequested`, so `Environment` does not depend on the service.

Checked against a local undertow build in an isolated config: detection, listing,
apply, a setting change, a rejected source, release, and the not-installed state.
Not checked: the Parallax panel itself with a web wallpaper centered, Niri and
Hyprland, and installing from GitHub.

## The desktop-widget rule

AGENTS.md excludes desktop background widgets. Live wallpapers are the stated
exception: they are wallpapers the user chooses, and nothing is available only
there. The System monitor scene reads the shared `SysStats` service, which keeps
its two-second detailed cadence while that scene is applied and returns to its
idle cadence otherwise. It shows local system readings only; nothing is collected
or sent anywhere. Aperture and the System instrument remain the way to read
telemetry while windows are open.

## Cost

Snowfall is GPU particles. Life paints one pixel per cell and scales it up. The
System monitor adds no poller of its own. The rest are 2D canvases painted below
screen resolution: Flow field, Constellations and Orrery at half resolution and
30 Hz, Deep field at half resolution and 20 Hz, Aurora at quarter resolution and
20 Hz. Flow field and Constellations do the most work per frame. None of this was
measured; treat the ordering as an estimate from the amount of drawing.

## Not verified

Rendering, settings and the background-layer window were checked in an isolated
Quickshell config on a KWin Wayland session. Not checked: Niri and Hyprland,
stacking against an already running awww or swww surface, pointer input on the
background layer under those compositors, the Options panel with a live scene
centered (no native render was taken), fractional scaling, and light mode.
The source tree was changed; nothing was installed and no running shell was
restarted.
