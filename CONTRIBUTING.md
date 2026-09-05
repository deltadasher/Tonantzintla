# Contributing to Tonantzintla

Tonantzintla is currently a private personal project, but changes should still be
treated like changes to a desktop environment rather than loose dotfile edits.

## Workflow

1. Start from a clean `main` checkout.
2. Create a focused branch for risky work.
3. Keep service, component, and surface changes in separate commits when
   practical.
4. Run `./tools/check`.
5. Confirm the live log ends in `Configuration Loaded` without a new warning.
6. Manually test open, close, keyboard focus, and the affected backend.
7. Commit only after the working state is reproducible.

Do not combine a layer-shell geometry rewrite with unrelated styling or service
polling changes. Prototype geometry and animation experiments outside the live
`EphemerisSurface.qml` first.

## Commit style

Use short imperative subjects with an optional subsystem:

```text
feat(ephemeris): add launcher origin transition
fix(audio): preserve the optimistic slider value
docs: explain laptop installation
chore: checkpoint working shell
```

## Publication and provenance

Tonantzintla is licensed under GPL-3.0-or-later. New third-party material must
arrive with explicit source, copyright, and license records.
