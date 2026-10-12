# Palmier Pro — Linux / Windows port

This fork ports [palmier-io/palmier-pro](https://github.com/palmier-io/palmier-pro)
(a macOS-only Swift 6.2 video editor) to Linux and Windows.
Branch: `port/linux-windows`.

## Status

| Platform | Target | State |
|---|---|---|
| Linux x86_64 | `PalmierPro` core binary + web timeline UI | Builds, `swift test` passes (228 tests) |
| Windows x86_64 | `PalmierPro` core binary + web timeline UI | Compiles via CI (`port.yml`), same portable core |
| macOS arm64 | Full app | Untouched code paths; verified by macOS CI job |

The portable core contains the timeline domain: models, project files,
ripple/overwrite engines, snap engine, timeline geometry, localization
infrastructure, utilities, and the pure parts of effects, text styles,
and volume mapping.

macOS-only (fenced, see below): SwiftUI/AppKit UI, AVFoundation media
pipeline, Metal kernels, MCP HTTP server (Network.framework), cloud
backends (Convex/Clerk), telemetry vendors, bundled MLX/speech models.

## Cross-platform UI

`Sources/PalmierPro/Server/` hosts a SwiftNIO HTTP server (non-macOS only)
on `http://127.0.0.1:19790/`:

- `GET /` — bundled canvas timeline (`Resources/Web/timeline.html`):
  ruler, tracks, clips, playhead scrub, wheel zoom, spacebar playback,
  clip selection.
- `GET /api/project` — demo project as JSON, encoded from the real
  `Timeline`/`Track`/`Clip` models.
- `GET /api/health` — liveness.

Run the binary and open the URL in a browser. This is the first UI layer;
native shells (Tauri) and editing operations come next.

## Layout

- Every file importing only Apple or closed third-party modules is wrapped
  in `#if os(macOS)` / `#endif` (mechanical pass, `guard_apple.py` kept out
  of tree).
- Hand-ported files use `#if canImport(...)` so macOS behavior is unchanged:
  `Utilities/Log.swift` (os_log → stderr on Linux),
  `Timeline/TimelineGeometry.swift`, `Timeline/SnapEngine.swift`
  (haptics fenced), `UI/AppTheme.swift` (numeric tokens portable, palette
  stays AppKit), `Models/TextStyle.swift` (data portable, font rendering in
  `TextStyle+AppKit.swift`), `Compositing/EffectOrdering.swift` (canonical
  order + `insertIndex`; CI descriptors stay macOS-only),
  `Localization/AppLocalization.swift` (`L10n.key` portable, bundle lookup
  macOS-only), `App/main.swift` (headless notice off macOS).
- `Package.swift` declares zero external dependencies off macOS, so the
  Linux/Windows core builds with a stock Swift toolchain.

## Build

Linux (Swift 6.2+):

```bash
swift build
swift test
./.build/debug/PalmierPro   # serves the timeline UI at http://127.0.0.1:19790/
```

Windows: same commands in the Swift toolchain (`swift.org`, 6.2+).
CI (`.github/workflows/port.yml`) builds and tests Linux + Windows and
compile-checks macOS on every push to `port/linux-windows`.

Some distros need shims for the Swift toolchain's expected sonames:

```bash
mkdir -p ~/lib
ln -sf /usr/lib/libncursesw.so.6 ~/lib/libncurses.so.6
export LD_LIBRARY_PATH=$HOME/lib
```

## Releases

Fork binaries are built from GPLv3 source in this branch, so they are
distributed under GPLv3 (see `LICENSE`). This differs from upstream, whose
post-v0.7.6 binaries are proprietary (`BINARY_LICENSE.md` covers upstream
binaries only, not fork builds).

## Roadmap

1. Core: portable domain + Linux/Windows binaries. Done (`v0.11.0-port.1`).
2. First UI layer: local HTTP API + canvas timeline in the browser.
   Done (`v0.11.0-port.2`).
3. Editing operations through the API (ripple/trim/split via the real
   engines), project files, native window shell.
