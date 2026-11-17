# Architecture

Book and Quill Notes is a Swift package with one thin executable and six
library modules. Dependencies only point downwards, and modules talk to each
other through protocols.

```
BookAndQuillApp  (entry point, dependency wiring)
      │
   BookUI  ──────────────┬──────────────┬──────────────┐
      │                  │              │              │
 BookStorage          BookAudio     BookAssets      BookCore
      │                  │
   BookCore          BookAssets
```

| Module | Responsibility | Knows about |
|---|---|---|
| `BookCore` | Domain models and rules: `Book`, `Page`, IDs and summaries, `BookLimits`, `LineWrapper`, `PageFitter`, `NameRules`, `ShelfLayout`. Pure value types, no UI, no file IO. | Foundation only |
| `BookStorage` | `LibraryRepository` protocol, `FileSystemLibraryRepository`, `InMemoryLibraryRepository` (test fake), atomic writes, file naming. | BookCore |
| `BookAudio` | `SoundPlaying` protocol, `AudioFileSoundPlayer` (AVFoundation), `SilentSoundPlayer`. | BookAssets |
| `BookAssets` | `AssetCatalog`: the single entry point to every texture, font and sound. All files live in `Sources/BookAssets/Assets`. | — |
| `BookUI` | SwiftUI screens, `@Observable` view models, pixel-art theme and components, drag and drop. | all of the above |
| `BookDebug` | Off-by-default debug facility: window snapshots (`WindowSnapshotter`), scripted scenarios (`Scenario`, `ScenarioRunner`), synthesized clicks and keys (`EventSynthesizer`), expectations. Drives the real UI and view models. See `docs/DEBUGGING.md`. | BookUI, BookCore |
| `BookAndQuillApp` | `@main`, `AppDelegate` (save on quit), `AppComposition` (the one place concrete types are chosen). | BookUI, BookStorage, BookAudio, BookDebug |

## Domain rules (BookCore)

- A page holds at most **256 characters** (grapheme clusters, newlines count)
  and **14 rendered lines**; a book holds at most **100 pages**.
- Line count is measured, not guessed: `LineWrapper` does greedy word wrapping
  over a `GlyphMeasuring` that returns each character's advance in GUI pixels,
  against a 114-pixel line (Minecraft's book width).
  - `MinecraftGlyphMetrics` is a reference table generated from the bundled
    font (used in tests and headless code).
  - `FontGlyphMeasurer` (BookUI) measures with CoreText through the real font,
    including system fallback fonts for non-ASCII characters.
- `PageFitter.applyEdit` applies an edit, or clips a paste to the longest
  prefix that still fits. An edit that makes an over-full imported page smaller
  is always allowed, so no data is ever stuck.
- `Book` exposes only rule-checked mutations (`setText`, `appendPage`, `sign`,
  `rename`). Signing is final: every later content edit throws `.signed`.

## Storage (BookStorage)

```
<root>/library.json                               chest order
<root>/<Chest>/chest.json                         shelf order
<root>/<Chest>/<Shelf>/<Book>.book/book.json      title, author, signed, dates, slot
<root>/<Chest>/<Shelf>/<Book>.book/pages/001.md   one plain-text file per page
```

- Identities (`ChestID`, `ShelfID`, `BookID`) are locations. Rename/move return
  the new identity. Moving a book or shelf moves the real folder.
- User names pass `NameRules`, then `FileNaming.sanitize` (illegal characters
  become `-`, no leading dots, max 80 characters) and `FileNaming.unique`
  (case-insensitive collision check, so the names become "Maths 2", "Maths 3").
- All writes go through `AtomicFileWriter` (temp file, `fsync`, then `rename(2)`).
  Pages are written only when changed, and stale page files are removed.
- Corrupted or missing `book.json` falls back to defaults (title = folder name),
  so pages stay readable. On the next save the bad file is kept as
  `book.json.corrupt-<timestamp>`. Corrupted order files are ignored. Folders
  added in Finder show up after the ones the order file lists.
- Duplicate or missing slots are repaired deterministically when listing (no writes).
- Deletes go to the Trash by default (`DeletionMode.moveToTrash`).

The in-memory fake follows the same rules, and `RepositoryContractTests` runs
the same tests against both implementations.

## UI (BookUI)

- `AppModel` owns the route (`chests` → `chest` → `book`) and the screen view
  models (`ChestListViewModel`, `ChestViewModel`, `BookEditorViewModel`). Views
  only render state and forward intents.
- Autosave: `BookEditorViewModel` saves 600 ms after the last edit and flushes
  on Done/back, when the app resigns active, on scene-phase change and on quit.
  If a save fails, the book stays open with its changes pending.
- The page editor is an `NSTextView` (TextKit 1), set up by `PageTextLayout`:
  pixel font at 8 pt × scale, 9 px line height and a 114 px container. Every
  edit is vetted in `shouldChangeTextIn` by the view model. As a second safety
  net, an edit that makes AppKit lay out more than 14 lines is reverted. A test
  checks that AppKit's line count equals `PageFitter`'s at scales 1 to 3.
- Pixel art: every texture is drawn with `.interpolation(.none)` at integer
  scales. The book screen picks the largest integer scale that fits the window
  and uses Minecraft's book-screen coordinates (`BookCanvasGeometry`).
- Drag and drop uses tagged string payloads (`DragPayload`), so text dragged in
  from other apps is ignored.
- Sounds reach plain views through the `playSound` environment value set by
  `RootView`. View models get a `SoundPlaying` injected.

## Swapping assets

Replace files in `Sources/BookAssets/Assets/{textures,fonts,sounds}` with the
same names (see `AssetCatalog`). Nothing else changes. `chest.png` and the app
icon are generated by `scripts/generate_placeholder_art.py` (`make art`).
