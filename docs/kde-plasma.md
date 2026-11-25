# Tonantzintla for KDE Plasma 6

Tonantzintla ships as a complete, native **KDE Plasma 6 Global Theme** alongside the Quickshell runtime.

## Included KPackages (`plasma/`)

| Component | Package ID / Name | Installed path (`$XDG_DATA_HOME`) |
| --- | --- | --- |
| Global Theme (Look & Feel) | `org.tonantzintla.desktop` (`Tonantzintla`) | `plasma/look-and-feel/org.tonantzintla.desktop` |
| Plasma Style (Desktop Theme) | `tonantzintla` (`Tonantzintla`) | `plasma/desktoptheme/tonantzintla` |
| Color Schemes | `TonantzintlaDark`, `TonantzintlaLight` | `color-schemes/Tonantzintla*.colors` |
| Window Decoration (Aurorae) | `Tonantzintla` | `aurorae/themes/Tonantzintla` |
| Wallpaper Package | `Tonantzintla` (`Tonantzintla Observatory`) | `wallpapers/Tonantzintla` |
| Native Plasmoids | `org.tonantzintla.{launcher,workspaces,media,clock,status}` | `plasma/plasmoids/org.tonantzintla.*` |
| Splash Screen | Bundled inside `org.tonantzintla.desktop` | `contents/splash/Splash.qml` |
| Desktop Layout | Top floating Aperture bar + centered bottom dock | `contents/layouts/org.kde.plasma.desktop-layout.js` |

## Commands

```bash
# Install all native KDE Plasma 6 theme packages and Plasmoids into ~/.local/share
blackhole plasma install

# Apply the full Tonantzintla KDE Plasma 6 theme (top bar, floating dock, wallpaper, colors, style, decorations)
blackhole plasma apply

# Apply theme colors/style/wallpaper while keeping your existing Plasma panels
blackhole plasma apply --keep-layout

# Apply light variant
blackhole plasma apply --mode light

# Sync your active Tonantzintla / Matugen palette into the installed KDE Plasma theme
blackhole plasma sync

# Inspect installation status or remove only Tonantzintla-owned Plasma packages
blackhole plasma status
blackhole plasma uninstall
```

Once installed, **Tonantzintla** also appears directly in **KDE System Settings → Colors & Themes** under Global Theme, Colors, Plasma Style, Window Decorations, Splash Screen, and Wallpaper.

## SDDM Login Screen

Tonantzintla's Umbra SDDM greeter remains managed separately via:

```bash
blackhole greeter install sddm
blackhole greeter activate sddm
```
