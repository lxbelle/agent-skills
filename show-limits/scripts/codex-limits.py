#!/usr/bin/env python3
"""Print the Codex account usage limits without an interactive session (show-limits skill).
Works wherever the `codex` CLI is installed and logged in (CLI or desktop login share ~/.codex).
Usage: codex-limits.py [--json]. Each reading is appended to $SHOW_LIMITS_LOG_DIR/codex.jsonl
(default ~/.cache/show-limits) so the next call prints the delta since the previous reading."""
import json, os, subprocess, sys, time
log_dir = os.path.expanduser(os.environ.get("SHOW_LIMITS_LOG_DIR", "~/.cache/show-limits")); os.makedirs(log_dir, exist_ok=True)
p = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
def send(o): p.stdin.write(json.dumps(o) + "\n"); p.stdin.flush()
def recv(i, timeout=30):
    t0 = time.time()
    while time.time() - t0 < timeout:
        l = p.stdout.readline()
        if not l: break
        try: m = json.loads(l)
        except Exception: continue
        if m.get("id") == i: return m
    return None
send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"clientInfo": {"name": "show-limits", "title": "show-limits", "version": "0"}, "capabilities": {}}}); recv(1)
send({"jsonrpc": "2.0", "method": "initialized"})
send({"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read", "params": {}})
r = recv(2); p.stdin.close(); p.terminate()
if not r or "result" not in r: sys.exit("no rate limit response: " + json.dumps(r)[:300])
res = r["result"]; rl = res["rateLimits"]; now = int(time.time())
prim = rl.get("primary") or {}; sec = rl.get("secondary") or {}
row = {"ts": now, "plan": rl.get("planType"), "primary_used": prim.get("usedPercent"), "primary_resets_at": prim.get("resetsAt"),
       "primary_window_mins": prim.get("windowDurationMins"), "secondary_used": sec.get("usedPercent"), "secondary_resets_at": sec.get("resetsAt"),
       "reset_credits": (res.get("rateLimitResetCredits") or {}).get("availableCount")}
if "--json" in sys.argv: print(json.dumps(res)); sys.exit()
lp = os.path.join(log_dir, "codex.jsonl"); prev = None
if os.path.exists(lp):
    lines = open(lp).read().splitlines()
    if lines: prev = json.loads(lines[-1])
open(lp, "a").write(json.dumps(row) + "\n")
def win(mins): return {300: "5h", 10080: "weekly"}.get(mins, f"{mins}min")
fmt = lambda t: time.strftime("%Y-%m-%d %H:%M", time.localtime(t)) if t else "?"
delta = "" if prev is None or prev.get("primary_used") is None else f" (was {prev['primary_used']}% at {time.strftime('%H:%M', time.localtime(prev['ts']))}, {row['primary_used'] - prev['primary_used']:+d} pts)"
line = f"Codex {row['plan']}: {win(row['primary_window_mins'])} {row['primary_used']}% used{delta}; resets {fmt(row['primary_resets_at'])}"
if row["secondary_used"] is not None: line += f"; secondary {row['secondary_used']}% (resets {fmt(row['secondary_resets_at'])})"
line += f"; free resets available: {row['reset_credits']}"
print(line)
