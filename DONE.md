# Done: round 2 (usable app, self-snapshots)

Verified on 2026-11-18 by running the commands below.

| Command | Result |
|---|---|
| `make test` | Pass. **126 tests** in four Swift Testing runs (40 + 34 + 12 + 40), 0 failures. (XCTest reports 0 tests; all are Swift Testing.) |
| `make app` | Pass. `build/BookAndQuill.app` built, signed and verified. |
| `make snapshot` | Pass. 5 of 5 scenarios (24 PNGs: first-book 13, reopen-app 2, saved-on-quit 0, organise 8, many-pages 1). |
| `make lint` | Runs, but **22 warnings remain** (indentation in `ChiseledBookshelfBlock.swift`, line breaks in `UITargets.swift`, one long line in `ExpectationChecker.swift`, one in `HostedView.swift`). No errors. |

## What changed
- **BookDebug**: the app photographs its own window and plays JSON scenarios through the real view models and UI, so the UI can be checked over SSH (`docs/DEBUGGING.md`).
- **Create-a-book bug fixed**, with regression tests and an end-to-end writing flow on the real file repository (`WritingFlowTests`).
- Empty states with clear first-chest and first-shelf prompts; New Book button, slot click and context menu all create a book and open it ready to type.
- Signed/read-only badge, rename/delete/drag safety tests, and two visual fixes found from screenshots (`docs/VISUAL_ISSUES.md`).

## Root cause of the book bug
The empty shelf slot was a `Color.clear` with a tap gesture. SwiftUI does not hit-test fully clear views, so clicks never arrived. The fix is `contentShape` before the gestures (`ShelfClickTests` clicks the real view with synthesized events). A second cause: after the new-book sheet closed, the page editor never got keyboard focus. `PageNSTextView` now claims focus from `viewDidMoveToWindow`.

## Running `make snapshot`
`make snapshot` builds the app, plays every file in `scenarios/` on throwaway temp libraries and writes PNGs to `snapshots/<scenario>/` (gitignored), plus `result.txt` per scenario. `make snapshot ONLY=organise` filters by name. Details in `docs/DEBUGGING.md`.

## Known gaps
- The delete-confirmation alert shows as a blank box in snapshots (`cacheDisplay` cannot draw native alerts). Not confirmed in a real window, so check by hand.
- The signed badge and a few later states have no snapshot scenario (covered by UI tests).
- 22 lint warnings remain (see above).
- Drag and drop, sounds and the page-flip animation have not been checked by hand in a real window. The scenarios synthesize the drops.
- Textures, font and sounds are Mojang placeholders: replace before sharing.
