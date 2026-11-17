# Book and Quill Notes

A native macOS app (SwiftUI, macOS 26) for uni notes, styled like Minecraft's
Book and Quill. Chests are semesters, shelves are subjects, books are lecture
notes, and pages are plain text: 14 lines, 256 characters, up to 100 pages.

> The textures, font and sounds are **Mojang-derived placeholders for personal
> use only**. See `Sources/BookAssets/Assets/README.md`.

## Commands

```
make build   # debug build
make test    # unit tests (Swift Testing)
make run     # run without a bundle
make app     # build/BookAndQuill.app (release, ad-hoc signed, icon, resources)
make snapshot # play scenarios/*.json in the real UI, write PNGs to snapshots/
make lint    # swift-format lint (make format to fix)
make art     # regenerate our own placeholder chest texture and app icon
```

The Makefile keeps SwiftPM's build folder in `~/Library/Caches/BookAndQuill-build`.
In an iCloud-synced folder like Desktop, plain `swift test` fails to codesign
its test bundles because of iCloud's extended attributes.

`make snapshot` lets the app photograph itself without Screen Recording
permission; see `docs/DEBUGGING.md`.

Notes are stored under `~/Documents/Book and Quill` (you can change this in
Settings). See `docs/ARCHITECTURE.md` for the design.
