# ArcWorks for macOS

ArcWorks is a native, SwiftUI-first 2D CAD application for macOS, using the CADCraft Rust engine.
Its product boundary follows AutoCAD LT: precision drafting, annotation, layers, blocks, layouts,
and plotting belong here; 3D solids, surfaces, meshes, modelling, and orbit tools do not. The
original cross-platform application remains beside it while the native interface grows.

## Open and run

1. Open `ArcWorks.xcodeproj` in Xcode.
2. Choose the `ArcWorks` scheme and **My Mac**.
3. Run the project.

The first build runs Cargo to compile `arcworks-bridge` as a static Rust library. Xcode then links
that library into the application. Rust must therefore be installed through `rustup`.

A verified local Release build is also placed at `dist/ArcWorks.app` from the repository root.

## Updating the CADCraft engine

The Git remotes deliberately have separate responsibilities:

- `origin` is the ArcWorks fork at `doobox/cadcraft`; `arcworks/main` is its protected working branch.
- `upstream` is the official `storytold/cadcraft` repository and is fetch-only.

Import each upstream release on an integration branch rather than directly on `arcworks/main`:

```sh
git fetch upstream --tags --prune
git switch arcworks/main
git switch -c update/cadcraft-vX.Y.Z
git merge --no-ff vX.Y.Z -m "merge: update CadCraft engine to vX.Y.Z"
cargo test -p arcworks-bridge
xcodebuild -project apps/arcworks-macos/ArcWorks.xcodeproj -scheme ArcWorks -configuration Debug build
```

After both builds pass, push the integration branch, fast-forward `arcworks/main`, and tag the
verified compatibility point as `arcworks-cadcraft-vX.Y.Z`.

## Current vertical slice

- Native CAD workspace shell with a compact unified toolbar, docked tool and property palettes, floating command line, and bottom model/status strip.
- Native New, Open, Save, and Save As workflows for DXF, DWG, and DWT drawings.
- Native Export workflow for PDF, SVG, and PNG output.
- macOS document ownership for DXF, DWG, and DWT, with ArcWorks file icons and Finder integration.
- Native unsaved-change protection for New, Open, external file opens, and Quit.
- Ten-minute background autosave with a native Drawing Recovery sheet after an abnormal shutdown.
- Persistent Open Recent history in the File menu and macOS document system.
- Native Undo and Redo menu actions with drawing-aware labels and standard macOS shortcuts.
- Selection-aware Cut, Copy, Paste, Delete, and Select All commands, with CAD objects mirrored through the macOS clipboard.
- Engine-backed command autocomplete with typing directly from the canvas, keyboard-highlighted suggestions, Tab completion, Up/Down recall, Space/Return execution, and an optional floating command-history panel toggled with F2.
- Optional, curated tool sidebar for drawing, modification, annotation, blocks, layers, and measurement.
- Canvas point input and object selection, including Shift selection, right-click/Return, and Escape.
- Live command rubber bands, running object-snap feedback, a CAD crosshair, and coordinate readout.
- CadCraft inference with hover-acquired points, polar/alignment/extension/parallel guides, and live tracking readouts.
- Engine-backed OSNAP, Ortho, Polar, Grid, Snap, Dynamic Input, and Object Snap Tracking controls.
- Standard drafting shortcuts: F3 for OSNAP, F7 for Grid, F8 for Ortho, F9 for Snap, F10 for Polar, F11 for tracking, and F12 for Dynamic Input.
- Direct keyboard input on the canvas with live distance and angle feedback during point commands.
- Blue window and green crossing selection drags, plus visible, draggable editing grips.
- Pointer-centred wheel and trackpad zoom, middle-button pan, keyboard zoom, double-middle-click/Zoom Extents, and visible selection highlighting.
- Existing CADCraft `Session`, command registry, document model, and renderer through a small C ABI.
- A MetalKit canvas that draws the Rust engine's real display list.
- The original CADCraft application remains unchanged.

The JSON render snapshot is intentionally a prototype boundary. The production renderer will
replace it with versioned contiguous vertex buffers for large drawings.

