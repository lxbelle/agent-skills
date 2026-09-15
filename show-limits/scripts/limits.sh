#!/bin/sh
# One call, two lines: Claude Code usage (from the status-line log) and Codex usage (app-server).
here="$(cd "$(dirname "$0")" && pwd -P)"
log="${CLAUDE_STATUSLINE_LOG:-$HOME/.claude/statusline-log.jsonl}"
python3 - "$log" <<'PY'
import json, sys, time
try:
    lines = open(sys.argv[1]).read().splitlines()
    d = json.loads(lines[-1]); p = d["payload"]; rl = p.get("rate_limits") or {}
    f, s = rl.get("five_hour") or {}, rl.get("seven_day") or {}
    ctx = (p.get("context_window") or {}).get("used_percentage")
    age = int(time.time() - d["ts"]); fmt = lambda t: time.strftime("%d.%m %H:%M", time.localtime(t)) if t else "?"
    stale = " STALE: no interactive Claude Code session is refreshing it" if age > 300 else ""
    print(f"Claude Code: 5h {f.get('used_percentage','?')}% (resets {fmt(f.get('resets_at'))}), 7d {s.get('used_percentage','?')}% (resets {fmt(s.get('resets_at'))}), context {ctx}%; sample {age}s old{stale}")
except Exception as e:
    print(f"Claude Code: no status-line sample ({e}); set up the statusLine per show-limits/SKILL.md")
PY
python3 "$here/codex-limits.py"
