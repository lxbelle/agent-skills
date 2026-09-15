#!/bin/sh
# Claude Code status line: log the payload for rate-limit tracking, print a short line.
log="$HOME/.claude/statusline-log.jsonl"
payload="$(cat)"
printf '{"ts":%s,"payload":%s}\n' "$(date +%s)" "$payload" >> "$log"
if [ "$(wc -l < "$log")" -gt 600 ]; then tail -n 500 "$log" > "$log.tmp" && mv "$log.tmp" "$log"; fi
printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("status"); sys.exit()
parts = [(d.get("model") or {}).get("display_name", "?")]
pct = (d.get("context_window") or {}).get("used_percentage")
if pct is not None:
    parts.append("ctx %.0f%%" % pct)
rl = d.get("rate_limits") or {}
for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
    v = rl.get(key)
    if isinstance(v, dict) and v.get("used_percentage") is not None:
        parts.append("%s %.0f%%" % (label, v["used_percentage"]))
print(" | ".join(parts))
'
