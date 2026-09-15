---
name: show-limits
description: "Read and report the usage limits of Claude Code (5-hour and 7-day windows) and Codex (weekly window, reset credits) from any agent role: a Claude Code manager launching Codex workers, a Codex manager launching Claude workers, or either running solo from a terminal or the desktop app. Use when the owner asks how much limit is left, when pacing worker rounds, or to decide whether to stop before a limit is exhausted."
license: MIT
metadata:
  version: "0.1.0"
---

# Show limits

Both hosts expose their subscription limits, but through different doors, and
neither door is the other's. This skill gives one command that prints both,
plus the reporting discipline the owner expects.

## Sources

| Host | Where the numbers come from | Works without an interactive session? |
| --- | --- | --- |
| Codex | `codex app-server` JSON-RPC method `account/rateLimits/read` (same data as the interactive `/usage-credits`): primary window `usedPercent`, `windowDurationMins`, `resetsAt`, optional secondary window, `planType`, `rateLimitResetCredits.availableCount` | Yes: any process that can run the `codex` CLI while the user is logged in (CLI or desktop app share `~/.codex`) |
| Claude Code | The status-line payload of an interactive session: `rate_limits.five_hour` and `rate_limits.seven_day` with `used_percentage` and `resets_at`, plus `context_window.used_percentage`. A status-line script writes it to `~/.claude/statusline-log.jsonl` | No: `claude -p` returns token usage only, never rate limits. The log is fresh only while an interactive Claude Code session is open (the status line re-runs every 60 s and after each turn) |

## Setup once per machine

1. Copy `scripts/` somewhere stable (the project's agent tooling directory or
   `~/.local/bin/show-limits/`); the scripts do not depend on this skill at run
   time.
2. Claude Code status line: install `scripts/claude-statusline-log.sh` as
   `~/.claude/statusline-log.sh` and add to `~/.claude/settings.json`
   (merge, do not replace other keys):

```json
"statusLine": { "type": "command", "command": "~/.claude/statusline-log.sh", "refreshInterval": 60 }
```

   The script appends `{"ts":…,"payload":…}` lines to
   `~/.claude/statusline-log.jsonl` (kept to the last 500 lines) and prints
   `Model | ctx N% | 5h N% | 7d N%` as the visible status line. Editing the
   user's settings is an authorized action; ask first when you are not the
   session the owner is talking to.
3. Codex: nothing beyond a logged-in `codex` CLI on PATH.

## Reading

```sh
scripts/limits.sh            # two lines: Claude Code (5h, 7d, context, sample age) and Codex (weekly, delta, resets, credits)
scripts/codex-limits.py      # Codex only; --json for the raw payload
```

`codex-limits.py` stores every reading in `$SHOW_LIMITS_LOG_DIR/codex.jsonl`
(default `~/.cache/show-limits`) and prints the change since the previous
reading, which is how "how much did this round cost" is answered without
relying on per-run token counts. `limits.sh` marks the Claude sample STALE
when it is older than 5 minutes.

## Who runs it, and what each role can see

- **Claude Code manager with Codex workers**: run `limits.sh` before and after
  every worker round. Both lines are live: the manager's own session refreshes
  the Claude log, and the Codex reading covers the workers (they share the
  account).
- **Codex manager with Claude workers** (`claude -p`): the Codex line is live.
  The Claude line is only as fresh as the last interactive Claude Code session;
  workers do not refresh it. Ask the owner to keep one interactive Claude Code
  session open during the batch (an idle one is enough) or to run `/usage`
  there when asked; report the sample age and never present a stale number as
  current.
- **Codex solo**, from the terminal or the desktop app: `codex-limits.py`
  works from any shell; inside the interactive CLI `/usage-credits` shows the
  same. The desktop app's own sessions count against the same weekly window.
- **Claude Code solo**: `/usage` in the interactive session, or `limits.sh` if
  the status line is installed.

## Reporting discipline (owner rule, 2026-09-15)

- Measure before and after every worker round and at least every 10 minutes
  during a long round. Report: local time, elapsed time of the current task,
  the two limit lines, and the delta since the previous reading.
- Do not narrate every action; one compact status per boundary.
- Stop dispatching and tell the owner when Codex's weekly window reaches 95%
  or either Claude window reaches 90%; the owner decides whether to wait for
  the reset or to spend a Codex reset credit. Never consume a reset credit
  (`account/rateLimitResetCredit/consume`, `/usage-credits`) on your own.
- If a limit is exhausted mid-round, the worker's own failure is the signal:
  record it as an environment failure, not a defect of the work, and resume
  after the reset without redoing accepted rounds.
