#!/bin/bash
# Plays every scenario in scenarios/ against build/BookAndQuill.app and writes
# window snapshots to snapshots/<scenario>/NN-step.png.
#
# Each scenario runs in its own app process on a throwaway library under a
# fresh temp folder; the real ~/Documents/Book and Quill is never touched.
# Scenarios with the same "library" share a folder, in file-name order, which
# is how "quit and reopen the app" is tested.
#
# Usage: scripts/snapshot.sh [scenario-name-filter]
set -u
cd "$(dirname "$0")/.." || exit 1

APP="build/BookAndQuill.app"
OUT="$PWD/snapshots"
FILTER="${1:-}"
TIMEOUT=120

[ -d "$APP" ] || { echo "missing $APP (run make app)"; exit 1; }
TMP="$(mktemp -d -t bookandquill-snapshots)"
rm -rf "$OUT"
mkdir -p "$OUT"

failures=0
for file in scenarios/*.json; do
    name="$(basename "$file" .json)"
    if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then continue; fi
    library="$(plutil -extract library raw -o - "$file" 2>/dev/null || echo "$name")"
    dest="$OUT/$name"
    mkdir -p "$dest" "$TMP/$library"

    # Run the binary directly rather than through `open`: a LaunchServices
    # launch would need Desktop folder permission to write into ./snapshots.
    "$APP/Contents/MacOS/BookAndQuill" \
        -ApplePersistenceIgnoreState YES \
        --library "$TMP/$library" \
        --scenario "$PWD/$file" \
        --snapshot-dir "$dest" 2>"$dest/stderr.txt" &
    opener=$!
    # Watchdog: a hung scenario must not hang the whole run.
    ( sleep "$TIMEOUT"; kill "$opener" 2>/dev/null ) &
    watchdog=$!
    wait "$opener"
    kill "$watchdog" 2>/dev/null
    wait "$watchdog" 2>/dev/null

    result="$(cat "$dest/result.txt" 2>/dev/null || echo "FAIL no result (timed out or crashed)")"
    count="$(find "$dest" -name '*.png' | wc -l | tr -d ' ')"
    printf '%-28s %s (%s snapshots)\n' "$name" "$result" "$count"
    [[ "$result" == PASS* ]] || failures=$((failures + 1))
done

echo "Snapshots in $OUT; throwaway libraries in $TMP"
exit "$failures"
