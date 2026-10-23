# Instrument customization correction

User direction: remove desktop background widgets entirely. Information belongs
in Aperture and on-demand instruments that remain useful beside applications.
Audit Serpantinum's post-2.0 visual/customization history and public author demos;
reinterpret useful principles without copying implementation or compositions.

Evidence: full source/release audit in work/reports/visual-upstream-audit.md,
public-demo access report in work/reports/visual-demo-audit.md, native-source gap
analysis in work/reports/tonantzintla-reinterpretation.md (task workspace).
Do not claim blocked TikTok video frames were watched. Distinguish features
already present in2.0 from later improvements and current source capabilities.

- [x] Remove desktop host/editor/model, settings/search/IPC/preferences, unused
  gauge and its sampler leases. Native legacy-enabled preference regression
  proves obsolete settings cannot reenable it and disappear on the next save.
- [x] Deploy removal locally while preserving other preferences and Niri config.
- [x] Finish the existing instrument context popup: actual material override,
  Resonance spectrum choice, Calendar starting mode, real Parallax transitions;
  replace inert controls and ensure keyboard/short-output reachability.
- [x] Expose the same context action through a small outside-content Customize
  handle and F10; preserve Super+Alt click and the invoking output.
- [x] Make Aperture island settings resolve the actual output/edge/arrangement.
- [x] Add semantic spectral-color overrides with explicit contrast validation,
  bounded native controls, actual Theme consumers, reset and appearance undo.
- [x] Native interactions/renders, full suite, independent review, refreshed
  evidence/patch and local deployment. Measure real-session RAM honestly.

Design boundaries: no new surface family, background window, poller, decoder or
secondary instrument preview. The visible instrument is the live preview.
Solid backing and readable text remain; controls stay translucent, input areas
stable, reduced motion settles immediately. Public baseline/config compatibility
is retained. Do not add night-light/display backends merely to fill a feature
list: these are substantial operations and were already present upstream2.0.

Native Wayland correction: the pre-existing separate context PanelWindow failed
real Escape routing and added fullscreen compositor buffers. Context now loads
as a bounded local overlay inside Ephemeris's existing native window and restores
its widget focus on dismissal. Actual private virtual-keyboard F10/Escape tests
and 20 open/close cycles passed; final memory gate is reported separately.

Completion evidence: final source248 Python/23 QtTest/40 Node/31 Rust passes,
no skips; actual installed dual-output normal workload385 samples/68 successful
commands,433.029120 MB peak QS+niri RSS. Settled-stage maximum416.309248 MB;
final421.683200 MB includes reopened Control optics. Helpers were not instrumented
locally; private helper-inclusive peak468.869120 MB remains separate. No real
lock/authentication, audio playback or physical display change was tested.
The later explicit native-still wallpaper work is a bounded opt-in background
renderer, not a return of the rejected desktop instrument/widget family.
