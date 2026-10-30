# Screen reading and unit conversion

Open **Optics bay** (Capture) for **Read text** and **Scan QR**. Select a screen
region; the result returns in the same instrument. Select text or press Copy.
QR contents are displayed as plain text and never opened automatically. Clear
removes the current in-memory result. Escape in the region selector cancels.

Text recognition uses Tesseract; QR decoding uses ZBar. Region selection uses
slurp and grim. All run only for the requested operation; no new polling service,
account, history database or telemetry is added. Temporary captured images are
removed after completion, cancellation and handled errors. A forced kill or power
loss can prevent cleanup. Copy intentionally passes the result to the system
clipboard, where the user's existing clipboard-history policy applies.

## Optional dependencies

The installer's **Local screen reading** group offers `tesseract`, an English
model, and `zbar` on supported Arch-family systems. Existing Tesseract installs
may still need a model. For example: `pacman -S tesseract-data-eng` (system install).
Other distributions use their package manager's equivalent packages.

The language button cycles installed model codes; Refresh checks again after
installation. User models also work in `$XDG_DATA_HOME/tonantzintla/ocr/` (default
`~/.local/share/tonantzintla/ocr/`). English is preferred when available. The shell
does not download language models automatically. Official model source:
[Tesseract tessdata_fast](https://github.com/tesseract-ocr/tessdata_fast).

QR text must be UTF-8. Non-text QR data is reported as unsupported. Several QR
codes can be returned from one area, separated by line breaks. OCR is best on a
small, legible block of text; recognition can contain mistakes.

## Unit conversion

Type a conversion directly in the launcher, then Enter to copy, or use the
existing Calculator to retain it in calculator history:

- `5 km to mi`
- `72 F to C`
- `1 GiB to MB`
- `3 imperial gallons to L`

Supports length, mass, temperature, volume, speed, and data. `MB` is megabytes;
`Mb` is megabits. Unqualified cups, spoons, fluid ounces, pints and gallons use US
customary units; imperial measures must be named explicitly. Incompatible units
are rejected. Conversions are fully offline; currency rates are not included.
