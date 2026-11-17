# Visual issues from `make snapshot`

Reviewed every PNG from the five scenarios (first-book, reopen-app, saved-on-quit, organise, many-pages). The Minecraft look (textures, font, buttons, book page) is faithful and was left alone.

## Fixed
- **Unreadable hint text** in the chest sidebar ("Drag a shelf's name onto a chest…") was drawn at scale 1 (about 4pt, illegible). Now uses the standard text scale and wraps. `ChestSidebar.swift`
- **Misaligned shelf name plate**: the plate's 6pt horizontal padding pushed the shelf icon and name 6pt right of the bookshelf blocks below. Only vertical padding remains, so the left edges line up. `ShelfRow.swift`

## Checked, not a defect
- Second book in a shelf sitting on the lower row (04-after-drags): the book was dropped on that slot by the scenario.
- "by Josh" left-aligned on the sign screen and the small header line above the editor: matches the reference layout.

## Known snapshot limitation
- The delete confirmation (04-organise/05) renders as a blank white box with only "Delete". It is a native SwiftUI alert; `cacheDisplay` cannot draw it faithfully, so this is a capture artefact, not verified as an app defect. Check by hand in the running app.
