# Memory budget and visual lifetimes

The target is the sum of **Quickshell and Niri RSS <=450,000,000 bytes**. Use decimal MB for this gate. Include every shell process during a lock or preview, and report shell-owned helpers separately. PSS and swap are useful additional measurements; they must not replace the RSS gate or silently hide shared/swapped memory. GPU allocations may live outside `/proc` RSS.

Run `python3 tools/memory-profile.py QS_PID NIRI_PID --samples 60 --interval 0.5` with the actual PIDs. Additional shell/owned-helper PIDs may be passed. The read-only tool checks process identity, rejects unavailable measurements and returns exit status 2 if any complete sample exceeds the budget. It does not change allocator settings or kill processes.

## Current measured scope,21 October2026

**The installed two-output workload passed the normal QS+niri RSS gate:**
**433.029120 MB peak** across385 samples and68 successful commands over82.33 seconds.
The settled stage peaked at416.309248 MB; the final421.683200 MB sample has
Control optics reopened, so it is not an idle measurement. Raw evidence is
`work/native-local-workload.json` (QS890363, Niri675406).

This run used1920×1080 and2560×1440 outputs, saved Vulkan/basic policy, native
prepared still wallpapers, instrument-scope Lens, Stacked clock and Arc telemetry.
It exercised settings pages, the lock editor only, launcher, Calendar/Media,
Parallax, notes/clipboard, island contexts, Bar Studio,20 Calendar lifetimes,
and a byte-identical wallpaper-copy transition followed by restoration of the
original path. Both outputs finish at generation4 with allPresented true, no
error and the original photo. `changed_preferences` is empty. The previous
external wallpaper daemon was manually retired after native frame acknowledgment.

Peak combined PSS was285.107200 MB; final PSS272.928768 MB; SwapPss stayed zero.
**Actual helper RSS was not instrumented.** The pass applies to the measured
normal two-process workload, not a universal ceiling, GPU memory total, helper-
inclusive total or secure-authentication workload. No real lock/authentication,
physical display configuration change or actual audio playback was tested.

Final source checks pass248 Python,23 QtTest reported passes (including
setup/cleanup),40 Node and31 Rust, with no skips. The separate private Vulkan/basic
run in `work/native-final-preview` records325 samples and193 successful commands:
390.639616 MB peak and361.668608 MB final QS+niri RSS. Its helpers peak140.890112 MB;
maximum simultaneous helper-inclusive RSS is **468.869120 MB** during first-use
wallpaper-library preparation. Peak PSS199.876608 MB, zero SwapPss, no final helpers.
That one-output private run also verifies different-image native replacement;
its isolated service warnings and113 Qt text-input warnings are disclosed in the
validation report. Its helper total must not be presented as a measured local total.

Earlier broad local builds exceeded450 MB, including478.609 MB before native still
integration. Those failures motivated the changes; they do not describe this
accepted build. Enabling native mode does not automatically kill an external
daemon. Three-channel awww BGR remains unsuitable on this host because Niri
advertises only four-byte wl_shm formats; pause does not trim its buffers.

## Resource rules

- Native still wallpaper is opt-in; the external renderer remains the default. Qt decodes only prepared PNGs, capped at2560px on the longest edge and requested at their exact validated dimensions. At rest each output has one full image. Replacement bridges through one512px old-image proxy, releases the old full image across a presented frame, loads the new full image, then unloads the proxy after a finite fade/grow/wipe/orbit reveal. Reduced motion/static fallbacks remain. Missing proxy refuses replacement while preserving the old image; failed new-image decode restores the old image and exposes Retry. No wallpaper screen capture, new resident process or idle animation timer is added. Video uses the external renderer after output-safe restoration; native is still-only.
- Desktop background widgets are excluded. Telemetry remains in Aperture and on-demand instruments; the existing detail sampler runs only while its System instrument is open.
- Editors, tools and tab content load on demand. Close destroys their models, effects and subscriptions. Spectrum uses the existing shared consumer and stops when no consumer remains.
- Etched control shading uses scene-graph primitives. Opt-in Frosted/Lens uses compiled shaders sampling one shared prepared wallpaper-still Image per active host, bounded to768px, with no screen capture or per-control render target. Rotated controls use an affine sampling basis. The classic instrument backing is a rounded scene-graph rectangle rather than a monitor-sized Canvas.
- Optical stills use an on-demand one-file job in the existing wallpaper helper. Qt receives only a validated prepared768px path, never the full original image. Providers share one preparation per source; the service caps active/pending sources and remembered results at four. The helper shares one decode lane with library indexing, exits after the job, and does not cause a startup library scan. Generation checks reject stale same-path results; explicit reapply/refresh invalidates success/failure caches. Pending/unavailable sources use the existing etched fallback. The original wallpaper and mapping are preserved; resampling may differ slightly.
- This moves full PNG decoding out of QS, not out of the machine: source-pixel caps and single-thread conversion remain, and temporary helper RSS must be counted separately.
- Album thumbnails and art have fixed decode bounds. Resonance blur and vignette are 256×256 source scenes. Parallax still thumbnails are generated at max 512px; satellite images decode at 256px and selected artwork at 512px. Temporary shuffle trails remain 192×192.
- Umbra's star field and fallback canvases have bounded source geometry. Its blur is 320×180. Optional video backgrounds use a prepared short silent animation loop on one output, with no in-process QtMultimedia decoder. Hidden loops are unloaded. Preparation is explicit/on-demand and cache entries are bounded; see the background editor for exact limits.
- Still thumbnail conversion inspects bounded headers before decoding: sequential JPEG can use reduced decoding, while non-reducible/progressive sources above 16 million pixels and unknown headers use the colour fallback. Preview absence never changes the original wallpaper apply path. Conversion uses one decoder/filter/encoder thread.
- No new always-running indexer, network refresher or status poller is introduced. File browsing is one directory at a time. Keyboard/radio OSD status accepts explicit events and provides one-shot hardware refresh.
- Notes/history/pins have count and size caps. Ordinary clipboard restoration streams and does not inherit the smaller pin storage cap.

## Acceptance procedure

Use the same output dimensions, scale, rendering backend, allocator settings, applications and playback state for comparisons. Start with a cold idle sample, then warm every instrument, media art and local wallpaper thumbnails. Exercise on-demand instruments and optional Umbra background animation. Repeat at least 20 open/close cycles, allow exit animations and allocator decay to finish, then compare settled memory. Inspect actual GPU-native captures as well as the measurements.

Actual shell launches (`blackhole run`, `lock`, and the supervisor's Quickshell child) append `narenas:2,dirty_decay_ms:0,muzzy_decay_ms:0` to inherited `MALLOC_CONF`. Unrelated options are preserved, and the supervisor/IPC environment is not globally changed. On jemalloc builds this releases unused pages promptly; the cost can be additional page faults/CPU when reusing allocations. No allocator library is injected or newly required. Other allocator builds may ignore this variable and need separate measurement. The development host's earlier wrapper used 1000 ms decay; the final launch policy uses zero decay. See the delivered benchmark evidence for that exact source policy.

A passing isolated nested-compositor run establishes only that tested configuration. It does not establish a universal 450MB ceiling for arbitrary monitor counts, codecs, media providers, drivers or a second secure-lock process. Before release/deployment, verify the actual session, high-DPI/multiple outputs and secure-lock lifecycle with explicit authorization. Never present a preview as an authentication test or a benchmark as proof of superiority to another shell without a matched comparison.

## Prior private measurement before prepared optical stills

The final private delivery workload sampled289 points at250 ms intervals on one
nested1686×1348 Wayland output. It launched through the saved `vulkan` preference
with both explicit and managed QSG environment variables removed before launch.
Native QRhi logs confirm hardware Vulkan on RX7800XT/RADV; loaded optics assertions
confirm GraphicsInfo.api5 and a ready shared shader texture.

Combined QS+niri RSS peaked at **371.965952 MB**, then finished at
**349.233152 MB** after an eight-second settle (QS210.034688 MB,
Niri139.198464 MB). Peak PSS was183.775232 MB; final PSS165.764096 MB;
SwapPss stayed zero. Temporary helpers peaked separately at140.877824 MB.
Maximum simultaneous QS+niri-plus-helper RSS was **462.888960 MB** during
first-use wallpaper indexing. No helpers remained in the final sample.

All178 recorded IPC/key commands succeeded, including20 real F10/Escape context
cycles. The workload covers Media/Calendar, semantic settings, wallpaper library,
Frosted/Lens controls, island context, Control optics, alternate bar faces,
10Calendar lifetimes, lock composition editor and silent feedback. It does not
exercise secure lock/authentication, prepared video playback, live system-bus
integrations or actual multi-output operation. The earlier matched renderer
experiment separately covered isolated clipboard and reopened Media; those checks
must not be attributed to this final workload.

The private two-process peak satisfies the450 MB target for this tested
historical configuration. Its helper-inclusive transient exceeds450 MB. The
subsequent actual installed acceptance is recorded at the top of this document.
This is not a universal ceiling or a claim about another shell's performance.
Raw evidence: `work/delivery-preview/{results.json,live-samples.json,
mapping-summary.json,qs.log}` in the delivery workspace. The log has no QML,
shader or device-loss failure. Expected isolated system-bus/PipeWire/portal errors
and113 Qt Wayland text-input disableSurface warnings are disclosed separately.

### Choosing and recovering a renderer

`blackhole graphics status|auto|opengl|vulkan` reads/saves only Tonantzintla's
next-start preference. Default `auto` leaves Qt selection untouched. An explicit
`QSG_RHI_BACKEND` takes precedence. The policy applies to shell/lock child launches,
not Niri or global application environments. It never restarts the shell and
status does not inspect the running renderer. For recovery, save `opengl` from a
terminal/TTY, remove any conflicting explicit override, then use the normal
start/restart command. `auto` restores automatic selection. Automatic recovery
from a failed Vulkan device is not implemented or claimed.

The earlier matched private OpenGL/Vulkan workload on this GPU measured
442.110/382.685 MB peak and418.263/362.422 MB settled QS+niri RSS. This supports a
machine-specific renderer choice, not an untested default across GPUs. The final
workload above uses newer complete source and a different output size; it is not
another matched estimate of the renderer saving. Font-subset and lazy-weather
component tests likewise establish their own bounded cases, not additive
whole-session RAM savings.


### Optional render loop

`blackhole render-loop status|auto|basic|threaded` independently saves the next-start
loop preference. Default auto preserves Qt choice; explicit `QSG_RENDER_LOOP`
wins. The same bounded atomic-file policy and owned-environment handling apply to
direct run/lock and supervisor children. `auto` is recovery after removing any
explicit override, followed by normal start/restart; the command itself does not
restart anything or inspect the current running loop.

[Qt documents](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html) that basic
shares GUI/render work on one thread, while threaded permits parallelism and
render-synchronized animation advancement. Basic changes animation timing and
can reduce retained resources; it is not an FPS improvement claim or a portable
replacement for auto. Final host captures, interactions and peak RSS remain
required after any local choice.
