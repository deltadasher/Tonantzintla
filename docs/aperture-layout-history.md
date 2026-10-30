# Aperture layout history

The bar studio keeps up to 50 layout edits for its current session. Undo and
Redo are available beside Done, with Ctrl+Z, Ctrl+Shift+Z and Ctrl+Y shortcuts.

History covers adding/removing islands, the studio's move/transfer operations,
layout presets and layout reset. Each entry restores both orientation layouts,
island placements, dock enablement and dock output together. No-op actions do
not consume history; a new edit after Undo discards the redo branch.

Changes made outside those studio operations (including direct live-bar dragging,
another output's editor and externally changed settings) clear the history rather
than risk overwriting the newer layout. Appearance, spacing and bar-position
settings are not part of layout undo. Closing the studio discards its history.
There is no new persistence, network access, sampler or background process.
