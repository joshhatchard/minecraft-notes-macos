# Book and Quill Notes: build brief

Build a native macOS app (SwiftUI, macOS 26, Xcode 27, Swift 6) for taking uni notes, styled exactly like Minecraft's Book and Quill. Personal use only for now (real Minecraft textures/sounds/font are allowed as placeholders, see Assets).

Project brief and log (read first, append to LOG.md as you go): ~/josh-brain/Projects/Book and Quill Notes/AGENTS.md and LOG.md.
Reference app for look and layout only (do NOT copy its code, it has no license): /tmp/bq-ref (Flutter). Read lib/widgets/page_sheet.dart and chiseled_bookshelf.dart for geometry and behaviour ideas.

## Product
Three-layer 2D hierarchy, like a file explorer:
- Chest = a semester. Shelf = a subject. Book = notes for a lecture/topic. Page = text.
- Screens: Chest list (home) -> open a chest -> shelves (bookshelf block UI with book slots, 6 per shelf like the reference's chiseled bookshelf) -> tap a book -> book editor.
- Drag and drop: books between shelves, shelves between chests. Create / rename / delete chests, shelves, books (with confirmation on delete).
- Book editor: the real Book and Quill page. Plain text only. 100 pages max, 14 lines per page, 256 characters per page max (enforce while typing, including wrapping so text never exceeds 14 rendered lines). Previous/next page arrows (page_forward/backward textures, highlighted on hover), page number "Page X of Y", add-page, flip animation + page_turn sound. Title, author, "Sign" which locks the book read-only (confirm first).
- Sound effects only: page turn, click, chest/book open (use insert/pickup), no music.
- Pixel-art rendering: nearest-neighbour everywhere (Image(...).interpolation(.none), integer scale factors), Minecraft font for text.
- No search. Mac only.

## Storage
Plain files, iCloud-ready but local first. Root folder (configurable, default ~/Documents/Book and Quill):
  <Chest name>/<Shelf name>/<Book name>.book/  (a folder package: book.json = title, author, signed, createdAt, updatedAt, slot index; pages/001.md, 002.md ...)
Ordering/slot metadata in small JSON. Atomic writes (write tmp then rename). Never lose data: autosave on change with debounce, safe on quit. Moving books/shelves = real folder moves. Handle name collisions and illegal filename characters.

## Architecture (senior-engineer quality, this is a hard requirement)
Swift Package with clear modules, no logic in views:
- BookCore: pure domain models and rules (Book, Shelf, Chest, Page, limits, text-wrapping/14-line fitting, validation). No UI, no file IO.
- BookStorage: repository protocol + file-system implementation (FileManager), plus in-memory fake for tests.
- BookAudio: protocol-based sound player (AVFoundation), with a no-op for tests.
- BookUI: SwiftUI views and view models (@Observable), pixel-art theme/components, drag and drop.
- App target: thin executable entry point, dependency wiring.
- Makefile: `make build`, `make test`, `make run`, `make app` (assemble a signed-adhoc BookAndQuill.app bundle with Info.plist, resources, icon placeholder), `make lint` if swift-format is available.
Use protocols at module boundaries, dependency injection, Swift concurrency correctly, no force unwraps in production code, no global singletons beyond the app root. Small files, clear names, doc comments on public API, a docs/ARCHITECTURE.md. No dead code, no TODO placeholders left behind, no vibe-coded shortcuts.

## Tests
Real unit tests (Swift Testing or XCTest) for: page text fitting/limits (14 lines, 256 chars, edge cases, unicode, newlines), page/book models, signing lock, file-system repository (temp directories: create/rename/move/delete, collisions, corrupted json, atomic write), view-model logic (navigation, add page, drag-move). Run `swift test` and make everything pass. Also verify `swift build` and that the .app actually launches (`open`, then check the process, then quit it); take a screenshot with `screencapture` if it works, otherwise say so.

## Assets
Staged in ./_staged_assets (textures/, fonts/, sounds/ as .wav). Move into the BookUI/BookAudio resource bundles via SwiftPM resources, behind ONE asset-catalogue layer (e.g. a `Theme`/`Assets` enum) so every texture, font and sound can later be swapped for redrawn ones by changing one folder. The reference repo has no chest texture: draw a simple pixel-art chest placeholder yourself (generate a PNG programmatically with a small script, own artwork), and also own icons where missing. Put a README in the assets folder saying these are placeholders from the reference app, personal use only, to replace before sharing.

## Working rules
- git init if needed, commit at meaningful milestones with clear messages. Create a .gitignore.
- Keep going until the whole app is built, tested and launching. Do not stop to ask about small choices: decide, and log the decision with the why in LOG.md (format in its header).
- Only stop for a BIG decision (something that changes product scope, costs money, needs credentials or is destructive). In that case write the question and your recommended default to BLOCKED.md in the project root and stop.
- When finished, write DONE.md summarising what was built, how to run it, test results, known gaps. Update the project AGENTS.md Status/Next steps.
- Add the repo path to AGENTS.md Links, and append the "Project log" block to the repo CLAUDE.md (create it).
