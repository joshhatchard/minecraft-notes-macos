#!/bin/bash
# Supervisor: bounded, phase-based Claude Code sessions.
cd ~/Desktop/BookAndQuill || exit 1
export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude-oauth-token)
CL=~/.local/bin/claude
TOOLS='Read,Edit,Write,Glob,Grep,Bash(swift *),Bash(xcodebuild *),Bash(make *),Bash(git *),Bash(mkdir *),Bash(cp *),Bash(mv *),Bash(ls *),Bash(cat *),Bash(find *),Bash(python3 *),Bash(open *),Bash(pgrep *),Bash(pkill -x BookAndQuill),Bash(osascript *),Bash(screencapture *),Bash(sips *),Bash(swift-format *),Bash(chmod *),Bash(codesign *),Bash(touch *),Bash(rm -rf .build*),Bash(rm -rf snapshots*),Bash(kill *),Bash(sleep *),Bash(defaults *),Bash(plutil *),Bash(mktemp *),Bash(swiftc *),Bash(xcrun *)'
for round in $(seq 1 6); do
  echo "=== round $round $(date) ===" >> build.log
  case "$round" in
    1) P="Read BRIEF2.md, inspect the current git diff and existing BookDebug files. Finish only the snapshot/debug facility and make snapshot command. Run its tests and make snapshot. Commit this phase. Do not redesign unrelated code." ;;
    2) P="Read BRIEF2.md and the current diff. Finish only the create-book flow. Reproduce the bug with a focused failing test, find the root cause, fix it, and run relevant tests. Verify create chest, shelf, empty slot, book editor. Commit this phase." ;;
    3) P="Read BRIEF2.md and current state. Finish only persistence and end-to-end book use: type, page limits, add/flip page, back, reopen, sign. Add focused tests, run them, commit. Do not spend time on visual polish." ;;
    4) P="Read BRIEF2.md and current state. Run make test, make build, and make snapshot. Inspect generated PNGs. Fix only concrete screenshot or launch failures. Commit." ;;
    5) P="Read BRIEF2.md and current state. Run day-one scenarios for empty states, rename/delete, book move, shelf move, and reopen. Fix only failing behaviour with focused tests. Run full tests. Commit." ;;
    6) P="Read BRIEF2.md and current state. Run final make test, make lint, make app, and make snapshot. If all acceptance criteria pass, write DONE.md with exact results and update docs/ARCHITECTURE.md, README.md, AGENTS.md and LOG.md. Otherwise fix the smallest remaining issues. Commit." ;;
  esac
  # Sonnet is the implementation model. Each phase starts fresh; repo/tests/log carry state.
  $CL -p "$P" --model sonnet --max-turns 40 --add-dir ~/josh-brain --allowedTools "$TOOLS" >> build.log 2>&1
  rc=$?
  [ -f DONE.md ] && { echo "STATUS: DONE" > status.txt; exit 0; }
  [ -f BLOCKED.md ] && { echo "STATUS: BLOCKED" > status.txt; exit 0; }
  if tail -80 build.log | grep -qi -E "usage limit|rate limit|limit reached|quota|overloaded"; then
    echo "STATUS: LIMIT" > status.txt; exit 2
  fi
done
echo "STATUS: ROUNDS_EXHAUSTED" > status.txt
