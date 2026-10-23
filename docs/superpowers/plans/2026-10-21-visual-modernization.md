# Visual modernization implementation plan
Goal: implement the researched post-Serpantinum-2.0 opportunities in the existing observatory interface, with bounded resource lifetimes.
Architecture: optional native QML instrument families, shared existing services and themed primitives; no new always-running subsystem for disabled features. All new preferences use Settings JSON persistence. Separate source changes from deployed runtime.
Global constraints: preserve real logo, solid panels, translucent controls, Parallax orbit, rounded artwork, Niri and init independence; no copied upstream code; no install/restart/authentication experiments.
Execution: user explicitly chose coordinated subagents. Independent file ownership permits concurrent work; coordinator owns shared persistence/composition and integration. Review each track and whole diff.

- [x] Reconcile existing uncommitted visual refinements against current public main, retaining current clearance/lifecycle behavior.
- [x] Measure running shell memory, inspect process tree/caches; fix proven lifecycle/image problems; add repeatable memory checks.
- [x] Shared control material/motion: optical translucent accents, stable hit areas, theme states and reverse transitions, no screen capture per control.
- [x] Remove the rejected desktop-background instrument feature: host/editor/settings/search/IPC/preferences, unused presentation code and its acquisition path. Preserve reusable clocks and visualizers only where existing Umbra/Resonance surfaces use them.
- [x] Umbra composition: layout editor, shared clock faces, optional battery/keyboard information, independent still/video background, preview, undo/redo; retain authentication boundary and expose fingerprint only with real support.
- [x] Everyday tools: launcher emoji/files, calculator history, notes pinning, clipboard pin/delete, OSD state indicators/placement, capture controls and feedback, media refinements, wallpaper transition choices.
- [x] Aperture/dock/settings/notifications/calendar polish: live style previews, layout consistency and clipping, notification actions/preview controls, sensible density and scaling.
- [x] Integration, behavioral tests, QML runtime/render checks, repeated open/close memory comparison, source deliverable and exact remaining hardware/runtime gaps.

Review focus: corrupt/oversized persisted data; disconnected outputs and fractional scale; fast repeated open/close with reduced motion; empty/offline/missing device states; hidden components retaining images, timers, or playback.

Final completion evidence: source248 Python/23 QtTest/40 Node/31 Rust passes,
no skips; installed dual-output normal workload433.029120 MB peak QS+niri RSS
across385 samples/68 successful commands. Settled-stage maximum416.309248 MB;
final421.683200 MB has Control optics reopened. Actual helper memory was not
instrumented; the separate private helper-inclusive peak was468.869120 MB.
Authentication/audio/physical-display tests and universal ceilings are not claimed.
