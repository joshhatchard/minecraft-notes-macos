# Round 2 brief: make it actually usable

Josh opened v1 and reports: **he cannot create a book from a shelf, so he can never write notes.** Also the UI has never been seen by anyone, because screencapture over SSH fails (no Screen Recording permission). Fix both, to the same senior-engineer standard as before (modular, readable, tested, no hacks, ARCHITECTURE.md kept current, decisions logged in the project LOG.md, commits at milestones).

## Part A: let us see the UI over SSH (do this FIRST)
`screencapture` cannot work headless here and we cannot change macOS permissions. Do not try to. Instead make the app able to photograph itself:
- Add a small debug facility (off by default, clearly separated module or file, e.g. BookDebug) that snapshots the app's own window(s) to a PNG using the app's own view hierarchy (NSView.bitmapImageRepForCachingDisplay / cacheDisplay on the window contentView, or CGWindowListCreateImage restricted to our own window ID, whichever works without Screen Recording permission). Trigger it with a launch argument like `--snapshot-to <path>` and ideally also a way to tell a running instance to snapshot (DistributedNotificationCenter or a command file).
- Add a scripted-scenario mode so we can drive the UI without Accessibility permission: `--scenario <name>` or a JSON list of actions (open chest, tap empty slot, type text, flip page, open sign sheet, drag a book...) executed through the real view-model and UI entry points, with a snapshot after each step. Reuse real code paths, no duplicate logic.
- Add `make snapshot` that builds the app, runs the scenarios against a throwaway temp library (never touch ~/Documents/Book and Quill), and writes PNGs to ./snapshots/ (gitignored). Document it in docs/ and the README.
- Then LOOK at the screenshots yourself (you can Read PNG files) and check every screen. Fix visual problems you see (clipping, misalignment, blurry scaling, z-order, unreadable text, hit areas).

## Part B: the real bug, creating a book
Reproduce it first with a failing test and a screenshot, find the root cause (do not paper over it), fix it, keep the regression test. Expected behaviour: in a chest, each shelf shows 6 slots; clicking an empty slot (and also a visible "New book" affordance and context menu item) creates a book in that slot and opens it in the editor immediately, ready to type. Verify the whole path end to end: create chest, create shelf, create book, type, flip/add page, back, reopen and the text persisted, sign. Verify with the real file-system repository in a temp dir. A fresh install with an empty library must have an obvious path to the first chest and first shelf (empty states with clear prompts).

## Part C: usability pass
Once A and B work, use the scenarios to walk through everything Josh will do on day one (first launch, first chest, shelf, book, writing several pages, closing and reopening the app, renaming, deleting, dragging a book to another shelf, moving a shelf to another chest) and fix anything broken, confusing or ugly. Add scenario coverage for each. Keep the Minecraft look faithful.

## Rules
Keep going until A, B and C are all done and verified by tests plus screenshots you personally looked at. Only stop for a BIG decision (scope, cost, destructive, credentials): write the question and your recommended default to BLOCKED.md and stop. Small choices: decide and log. When finished, write DONE.md (what changed, root cause of the book bug, how to run `make snapshot`, test counts, known gaps) and update the project AGENTS.md status/next steps and LOG.md.
