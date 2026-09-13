# Working on Tonantzintla

Before implementation, read [the agent design guide](docs/agent-design-guide.md)
and [architecture](docs/architecture.md). For visual tasks, also read the dated
[surface audit](docs/visual-audit-1.1.md). Research observations are not automatic
authorization to redesign working surfaces.

## Non-negotiables

- Tonantzintla is the project name; `blackhole` is the public command. Historical
  Astralith references and migration compatibility are not permission to rename it back.
- Preserve the real logo, Parallax's orbit, expressive morphing, solid instrument
  backgrounds, translucent controls, and Resonance's rounded clipping.
- Do not restore Chronos or the diamond's duplicate telemetry sidepanel.
- Inspect the current branch, dirty tree, source and installed runtime separately.
  Preserve existing changes. Commit, push, install, restart and rewrite history
  only when the current request authorizes those actions.
- Put state/integrations in services and helpers; keep shell.qml as composition.
  Avoid new global pollers, duplicate daemons and machine-specific defaults.
- Settings must affect a real consumer and expose pending, unsupported and failure
  states. Never claim a configuration write proves the external system applied it.
- Test proportionally. QML compilation is not visual verification; a fake idle
  process is not a proven session lock. Report exactly what was and was not tested.
- Never activate a real lock or suspend test without making the interruption clear
  and establishing the user's consent. Never weaken authentication for convenience.
- Borrow upstream principles, not branding or unreviewed source code. Check license
  compatibility before copying code. Keep evidence and design proposals distinct.

The guide records accepted constraints and research as of 2026-09-05. Verify
time-sensitive implementation details against the current checkout before acting.
