# Screen reading, conversions, and visual research

User-authorized implementation: local OCR and QR inspection in Optics bay; offline unit conversion in launcher/calculator; evidence-indexed visual interpretations. Preserve existing native visual identity, no background widgets or telemetry.

1. Build bounded on-demand OCR/QR helper, with missing-tool/language states, cancellation, temporary-file cleanup, no auto-opening or clipboard mutation.
2. Add a transient singleton process owner and keyboard-accessible extraction/result pane inside CaptureWidget. Keep text in memory, explicit copy/clear, no idle work.
3. Share a pure unit parser between launcher and calculator; test ambiguous and incompatible units, keyboard acceptance.
4. Index upstream visual mechanisms with pinned evidence and actual Tonantzintla equivalents. Adapt transient audio response and wallpaper palette preview where useful.
5. Verify tests and rendered native UI, reconcile source/runtime separately, back up touched files, install targeted changes through the existing Shellswitch payload without starting a duplicate shell.
