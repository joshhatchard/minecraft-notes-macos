#!/bin/bash
# Supervisor: runs Claude Code in rounds until DONE.md / BLOCKED.md appears or limits hit.
cd ~/Desktop/BookAndQuill || exit 1
export CLAUDE_CODE_OAUTH_TOKEN=$(cat ~/.claude-oauth-token)
CL=~/.local/bin/claude
TOOLS='Read,Edit,Write,Glob,Grep,Bash(swift *),Bash(xcodebuild *),Bash(make *),Bash(git *),Bash(mkdir *),Bash(cp *),Bash(mv *),Bash(ls *),Bash(cat *),Bash(find *),Bash(python3 *),Bash(open *),Bash(pgrep *),Bash(pkill -x BookAndQuill),Bash(osascript *),Bash(screencapture *),Bash(sips *),Bash(swift-format *),Bash(chmod *),Bash(codesign *),Bash(touch *),Bash(rm -rf .build*)'
for round in $(seq 1 12); do
  echo "=== round $round $(date) ===" >> build.log
  if [ $round -eq 1 ]; then
    P="Read BRIEF.md in this directory and build the whole app exactly as specified. Keep going until DONE.md is written."
    $CL -p "$P" --model opus --max-turns 80 --add-dir ~/josh-brain --allowedTools "$TOOLS" >> build.log 2>&1
  else
    $CL -p "Continue the build per BRIEF.md. Check git log, LOG.md and test state, then finish remaining work. Write DONE.md when complete." --continue --model opus --max-turns 80 --add-dir ~/josh-brain --allowedTools "$TOOLS" >> build.log 2>&1
  fi
  rc=$?
  [ -f DONE.md ] && { echo "STATUS: DONE" > status.txt; exit 0; }
  [ -f BLOCKED.md ] && { echo "STATUS: BLOCKED" > status.txt; exit 0; }
  if tail -40 build.log | grep -qi -E "usage limit|rate limit|limit reached|quota|overloaded"; then
    echo "STATUS: LIMIT" > status.txt; exit 2
  fi
done
echo "STATUS: ROUNDS_EXHAUSTED" > status.txt
