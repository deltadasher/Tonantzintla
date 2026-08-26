# Provenance and public-release audit

Status checked on 2026-08-25.

## Result

The known unlicensed Serpantinum/`imperative-dots` adaptation points have been
reimplemented. A normalized five-line source comparison against the local
upstream checkout at `eefff2fadceb28b52198175914576fbb55f57695` now reports no
matching implementation blocks in Astralith's QML, JavaScript, Python, or shell
sources.

The upstream repository did not expose a `LICENSE` or `COPYING` file at audit
time. Astralith therefore carries no upstream source, preset table, image, or
derived search implementation from that project. Serpantinum remains a
historical product and behavior reference only.

This is a best-effort engineering provenance review, not a legal opinion.

## Reimplemented boundaries

- `modules/ephemeris/widgets/shared/OrbitalForecast.qml` now uses Astralith's
  independently designed single-orbit composition and radial choreography.
- `scripts/equalizer-state.py` and `services/Equalizer.qml` now use original
  Astralith listening profiles and logarithmic band interpolation. None of the
  former upstream preset constants remain.
- `scripts/wallpaper-online.py` now uses Wikimedia Commons' documented MediaWiki
  API and preserves source-page, artist, and license metadata. It no longer
  implements Serpantinum's DuckDuckGo token-scraping flow.

The Flight Manual and parity documentation may still name Serpantinum when
describing historical inspiration or feature comparison. Names, ideas, and
behavioral compatibility are not bundled upstream expression.

## Asset review

- No Astralith wallpaper or icon hashes match files in the local Serpantinum
  checkout or running configuration.
- The six bundled space wallpapers are project-generated artwork documented in
  `wallpaper-flight-pack-01.md`.
- The static Flight Manual black-hole illustration is project-generated artwork.
- The compact controls under `assets/icons/` are unmodified GNOME
  AdwaitaLegacy icons. Their source, per-file mapping, attribution, and selected
  CC BY-SA 3.0 license are recorded in `THIRD_PARTY.md`.
- Online wallpaper downloads are user data and are never committed by the
  helper. Individual Commons results retain their own licenses.

## Licensed optional integration

The optional native Ephemeris silhouette renderer builds the unmodified
`Caelestia.Blobs` C++ and shader sources from Caelestia Shell at pinned commit
`1d0e5a588c61f1d905eba5fe8446ec222d37f50c`. Caelestia Shell is GPL-3.0.
Astralith keeps that renderer outside the core runtime, downloads the complete
upstream checkout into the user's cache, retains its license and attribution,
and enables it only after a successful local build.

No Caelestia implementation source is tracked by Astralith. A distributor that
bundles or enables the native renderer must still satisfy GPL-3.0; the pure-QML
fallback has no Caelestia runtime dependency.

## Remaining release decisions

- Select Astralith's own license before inviting reuse or contributions. Making
  source visible without a license does not grant downstream reuse rights.
- Decide whether the repository ships Niri configuration or treats it as an
  optional example.
- Choose supported distributions and verify exact dependency package names.
- Decide whether generated wallpapers remain in the main repository or move to
  a separate artwork package as the library grows.
