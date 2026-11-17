# Debugging and snapshots

`screencapture` needs Screen Recording permission, which a headless SSH session
can't have. So the app can photograph itself: `BookDebug` renders the app's own
window with `cacheDisplay` and drives the real UI with scripted scenarios.
Nothing in `BookDebug` is active unless a launch argument is passed.

## Running

```
make snapshot                  # build the app, play every scenario, write PNGs to snapshots/
make snapshot ONLY=organise    # only scenarios whose name contains "organise"
```

Each scenario runs in its own app process against a throwaway library in a temp
folder. `~/Documents/Book and Quill` is never touched. `snapshots/` is
gitignored. Output per scenario: `snapshots/<name>/NN-step.png`, `result.txt`
(`PASS` or `FAIL <reason>`) and `stderr.txt`. The script's exit code is the
number of failed scenarios. Scenarios sharing a `"library"` value share a
folder, in file-name order, which is how "quit and reopen" is tested.

## Launch arguments

| Argument | Effect |
|---|---|
| `--library <dir>` | Use this folder as the library |
| `--scenario <file.json>` | Play a scenario, then quit |
| `--snapshot-dir <dir>` | Where scenario snapshots go |
| `--snapshot-to <file.png>` | Snapshot the window once after launch |
| `--listen-for-snapshots <dir>` | Snapshot on request into a running app |

## Scenario files (`scenarios/*.json`)

`{"name": ..., "library": ..., "steps": [...]}`. Steps go through the real view
model and UI entry points:

`click`, `contextMenu` + `item`, `type`, `key` (+ `modifiers`), `alertButton`,
`dragBook` + `toShelf` + `slot`, `dragShelf` + `toChest`, `resize`, `wait`,
`snapshot`, `expect` (route, names, sheet, `typingIntoPage`, `pageText`,
`pageLabel`, ...). Expectations poll for up to 3 s.

## Known limitation

The native delete-confirmation alert is captured as a blank box with only the
Delete button, because `cacheDisplay` can't draw it. Check it by hand.
