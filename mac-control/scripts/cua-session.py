#!/usr/bin/env python3
"""Minimal MCP stdio client for cua-driver: run several tools in ONE driver session from a shell.
Usage: cua-session.py <tool> <json-args> [<tool> <json-args> | x sleep=N ...]
  "@find:ROLE:LABEL"  -> element_token of the first element of the last get_window_state whose role matches and label starts with LABEL
  "@newest_window"    -> highest window_id from the last list_windows
  CUA_RAW=1           -> print raw elements (with frames) for get_window_state; MCP_LIMIT=N truncates printed results
  CUA_DRIVER=/path    -> driver binary (default ~/.local/bin/cua-driver), always launched as `mcp --direct`.
Element tokens live only inside one session, so snapshot and act in the same invocation."""
import json, os, subprocess, sys
cmd = [os.path.expanduser(os.environ.get("CUA_DRIVER", "~/.local/bin/cua-driver")), "mcp", "--direct"]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
def send(obj):
    p.stdin.write(json.dumps(obj) + "\n"); p.stdin.flush()
def recv(want_id):
    while True:
        line = p.stdout.readline()
        if not line:
            err = p.stderr.read()
            raise SystemExit(f"driver exited: {err[-2000:]}")
        try: msg = json.loads(line)
        except Exception: continue
        if msg.get("id") == want_id: return msg
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcpcall","version":"0"}}})
recv(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"})
args = sys.argv[1:]
i = 2
last_elements = []
last_windows = []
def resolve(v):
    if v == "@newest_window":
        return max(w["window_id"] for w in last_windows)
    # "@find:ROLE:LABEL" -> element_token of the first matching element of the last snapshot
    if isinstance(v, str) and v.startswith("@find:"):
        _, role, label = v.split(":", 2)
        for e in last_elements:
            if e.get("role") == role and (e.get("label") or "").startswith(label):
                return e["element_token"]
        raise SystemExit(f"no element {role} {label!r} in last snapshot ({len(last_elements)} elements)")
    if isinstance(v, dict): return {k: resolve(x) for k, x in v.items()}
    return v
while args:
    tool, raw = args[0], args[1]; args = args[2:]
    if raw.startswith("sleep="):
        import time; time.sleep(float(raw[6:])); continue
    send({"jsonrpc":"2.0","id":i,"method":"tools/call","params":{"name":tool,"arguments":resolve(json.loads(raw))}})
    r = recv(i); i += 1
    out = r.get("result", r.get("error"))
    if tool == "list_windows" and isinstance(out, dict):
        last_windows = out.get("structuredContent", {}).get("windows", [])
        print("== list_windows == " + ", ".join(f"{w['window_id']}{'*' if w['is_on_screen'] else ''}" for w in sorted(last_windows, key=lambda w: -w['window_id'])[:5]))
        continue
    if tool == "get_window_state" and isinstance(out, dict):
        last_elements = out.get("structuredContent", {}).get("elements", [])
        if os.environ.get("CUA_RAW"):
            print("== get_window_state (raw elements) ==")
            for e in last_elements:
                if e.get("role") in ("AXButton", "AXTextField", "AXCheckBox", "AXStaticText"):
                    print(json.dumps({k: v for k, v in e.items() if k != "children"}, ensure_ascii=False)[:300])
            continue
        print(f"== get_window_state == {len(last_elements)} elements; " + "; ".join(f"{e.get('role')}:{(e.get('label') or '')[:30]}" for e in last_elements if e.get('role') in ('AXButton','AXTextField','AXCheckBox') and e.get('label'))[:1500])
        continue
    text = json.dumps(out, ensure_ascii=False)
    limit = int(os.environ.get("MCP_LIMIT", "6000"))
    print(f"== {tool} ==\n{text[:limit]}{'…' if len(text) > limit else ''}")
p.stdin.close(); p.wait(timeout=10)
