# Wayland compatibility research for 1.5

Research note: 2026-09-25. This records planning ideas only; it makes no runtime or shell changes. The target is broad support for Wayland desktop sessions, with rendering features that degrade safely when a compositor or GPU does not provide a needed capability.

## Findings

### Wayland compatibility has separate layers

Wayland core is intentionally small. Desktop behavior is extended by protocols, and compositors implement different sets of extensions. The `wayland-protocols` project explicitly tracks protocols through experimental, staging, stable, and deprecated phases. The `wlr-layer-shell-unstable-v1` protocol is a separate wlroots protocol for desktop-shell surfaces; it provides anchoring, layer ordering, and input semantics, but its presence is not implied by a generic Wayland session.

This means “runs as a Wayland client” and “can implement every desktop-shell feature” are separate support claims. A normal application window can use the standard desktop shell role while bars, OSDs, lock screens, workspace controls, and output management need additional compositor support or an adapter. Do not promise all features merely because `WAYLAND_DISPLAY` is set.

Sources: [Wayland protocol extensions and maturity](https://github.com/wayland-mirror/wayland-protocols), [wlroots layer-shell protocol](https://github.com/swaywm/wlroots/blob/master/protocol/wlr-layer-shell-unstable-v1.xml), [Qt’s description of Wayland shell roles](https://doc.qt.io/qt-6/qtwaylandcompositor-shellextensions.html).

### Qt Quick and GLSL can span graphics APIs, with build-time shader conditioning

Qt Quick 6 renders through the Qt Rendering Hardware Interface (RHI), which can target OpenGL, OpenGL ES, Vulkan, Direct3D, and Metal. Qt Shader Tools’ `qsb` compiles Vulkan-style GLSL to SPIR-V and can package translated shader variants for the target APIs. A `.qsb` containing only SPIR-V is Vulkan-only; Qt’s documented common target set for Qt Quick effects is GLSL ES 100, GLSL 120/150, HLSL 50, and MSL 1.2 (`qsb --qt6`). Keep shader source and reproducible build instructions alongside the packaged `.qsb`; inspect the package to confirm its variants.

Qt’s software adaptation does not render `ShaderEffect`. Therefore shader effects need an explicit non-shader visual path if the shell is to remain usable in software rendering or when shader creation fails. This is a feature fallback, not full visual parity.

Sources: [Qt Shader Tools overview](https://doc.qt.io/qt-6/qtshadertools-overview.html), [qsb manual](https://doc.qt.io/qt-6/qtshadertools-qsb.html), [Qt Quick software adaptation](https://doc.qt.io/qt-6/qtquick-visualcanvas-adaptations-software.html), [Qt graphics APIs](https://doc.qt.io/qt-6/topics-graphics.html).

### Qt Quick 3D adds a hard GPU capability boundary

Qt Quick 3D uses the same RHI selection path as Qt Quick. Qt documents OpenGL 3.0+ (3.3 recommended), OpenGL ES 2.0+ (3.0 recommended), Vulkan 1.0+, Direct3D 11.1/12, and Metal 1.2+. The Qt Quick software adaptation does not support 3D content. ES 2.0 has a reduced feature set, including limits on image-based lighting, shadows, SSAO, post-processing, and shader features.

Recommendation: keep the shell’s essential 2D Wayland UI independent from Quick 3D scene creation. Gate 3D modules on actual graphics capability, provide a 2D or static fallback, and test process startup with the feature disabled as well as enabled. Do not silently force one RHI backend globally; Qt documents that a forced backend can fail if unavailable.

Source: [Qt Quick 3D graphics requirements](https://doc.qt.io/qt-6/qtquick3d-requirements.html).

## Repository-specific observations

- The project is currently described as a Niri/Quickshell shell, and dependencies list Niri. Its architecture document says compositor adapters should contain only supported adapters.
- `src/quickshell/services/Compositor.qml` directly reads `NIRI_SOCKET` and implements Niri’s JSON event/action protocol. Workspace and window features therefore cannot become compositor-neutral by changing only the Wayland window backend.
- Many surfaces use Quickshell `WlrLayershell` properties for layer order and keyboard focus. This is a shell-protocol dependency, distinct from Qt Quick rendering. Inventory every such surface before adding another backend.
- `src/quickshell/umbra-lock.qml` uses Quickshell’s session-lock surface types. Lock support must remain a separately verified security capability; never replace a missing secure-lock protocol with an ordinary overlay window.
- The newly added gravity shader currently has a classic-panel path and checks for Qt’s software graphics API. Preserve this kind of fallback as GLSL and 3D features expand.

These are source-tree observations, not confirmation of behavior on any compositor or GPU.

## Suggested 1.5 direction

1. Define support levels rather than one binary “Wayland compatible” label:
   - **Wayland client:** shell starts with Qt’s Wayland platform plugin and ordinary windows work without XWayland.
   - **Desktop-shell surfaces:** bars, anchored popovers, OSD, and notifications work through an available layer-shell protocol adapter.
   - **Compositor integration:** workspaces, windows, output controls, and actions work through a named backend (initially Niri); unavailable capabilities show as unavailable.
   - **Secure session features:** lock screen is enabled only with the compositor’s real session-lock protocol and validated authentication flow.
   - **Graphics features:** GLSL and Qt Quick 3D are tested per RHI/backend and fall back independently.
2. Introduce a capability-oriented compositor interface. Separate generic state and widgets from backends for Niri IPC, layer-shell surface roles, session lock, output management, idle, screenshots, and clipboard. Probe support at runtime; do not infer all capabilities from compositor name or environment variables alone.
3. Build a small support matrix before promising breadth. Candidate representative environments: Niri, Sway or another wlroots compositor, KDE Plasma/KWin, and GNOME/Mutter. Record compositor/version, Qt/Quickshell versions, GPU/driver, RHI API, display scaling, and each feature’s status. An app window starting on each one does not validate shell roles or lock security.
4. Keep graceful degradation explicit: unsupported features should be disabled with a clear reason; critical ordinary-window/settings behavior should remain available. Never use XWayland-only behavior as a silent fallback for shell control, global input, or secure lock.
5. For shader and 3D assets, make shader baking reproducible in the build, package the `.qsb` assets, validate required variants, and avoid runtime shader compilation as the default. Test GLSL and Quick 3D on at least OpenGL and Vulkan where available, plus software-rendered 2D startup. Test low-capability GPU paths and missing shader resources.
6. Make compatibility claims from live compositor evidence. Static QML compilation or software startup proves neither layer-shell acceptance nor GPU rendering nor secure session lock.

## Suggested acceptance gates

- Launch a native Wayland client with XWayland unavailable; confirm no accidental X11 platform selection.
- Exercise every surface role on each claimed compositor: bar, full-screen host, popover focus, OSD, notifications, and dismissal/input regions.
- Test multi-output, hotplug, fractional scale, mixed scale, and output removal/reconnect.
- Test compositor IPC absent, disconnected, restarted, and unsupported; generic UI should remain usable.
- Validate secure lock only on compositors exposing the required session-lock protocol; test wrong password, cancellation, output hotplug, and failure recovery.
- Bake and inspect each `.qsb`; render on target RHI backends and check shader-error fallback. Ensure the classic 2D path works under Qt’s software adaptation.
- Run Quick 3D only where supported; verify clean feature disablement and 2D fallback on software rendering and unsupported hardware.

## Primary references

- [Wayland protocol extensions](https://github.com/wayland-mirror/wayland-protocols)
- [wlroots layer-shell XML specification](https://github.com/swaywm/wlroots/blob/master/protocol/wlr-layer-shell-unstable-v1.xml)
- [Qt Wayland shell extensions](https://doc.qt.io/qt-6/qtwaylandcompositor-shellextensions.html)
- [Qt graphics APIs](https://doc.qt.io/qt-6/topics-graphics.html)
- [Qt Shader Tools overview](https://doc.qt.io/qt-6/qtshadertools-overview.html)
- [Qt qsb manual](https://doc.qt.io/qt-6/qtshadertools-qsb.html)
- [Qt Quick software adaptation](https://doc.qt.io/qt-6/qtquick-visualcanvas-adaptations-software.html)
- [Qt Quick 3D graphics requirements](https://doc.qt.io/qt-6/qtquick3d-requirements.html)
