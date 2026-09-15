---
name: mac-control
description: "Drive macOS desktop applications from an agent without stealing the user's focus: install and register cua-driver as an MCP server for Claude Code and Codex, snapshot windows through Accessibility, click, type and verify in the background, and fall back to real HID input only for pointer-level checks. Use for GUI inspection and manual-style testing of native, Tauri, Electron or browser apps on the user's Mac; not for mobile devices or headless web testing."
license: MIT
metadata:
  version: "0.1.0"
---

# Mac control

Goal: inspect and operate a running macOS application while the user keeps
working in the foreground. Nothing here activates, raises, moves or resizes a
window, moves the hardware cursor or types into whatever window happens to be
in front. The driver is `cua-driver` (trycua/cua, MIT); both Claude Code and
Codex reach it through MCP, so one installation serves every project.

## Install once per machine

An agent can do the whole installation from this file, but three steps stay
with the human; ask for them up front instead of failing halfway:

1. Authorization for the writes and network the install needs: the source
   clone, `cargo build` fetching crates, the binary in `~/.local/bin`, and the
   MCP registration in `~/.claude.json` / `~/.codex/config.toml`. Codex runs
   sandboxed without network or writes outside the project by default.
2. macOS permissions: Accessibility and Screen Recording for the terminal or
   client that spawns the agent (System Settings → Privacy & Security), then a
   restart of that terminal.
3. A new agent session after registration: MCP tools are loaded at start.

Prerequisites: Rust via rustup (the repository pins its own toolchain), Xcode
Command Line Tools. Check the latest `cua-driver-rs-v*` tag on the releases
page and pin it below.

Build from source at a pinned release tag rather than piping the vendor's
installer to a shell (it verifies no checksum):

```sh
git clone --depth 1 --branch cua-driver-rs-v<version> https://github.com/trycua/cua.git ~/w/src/cua
cd ~/w/src/cua/libs/cua-driver/rust && cargo build -p cua-driver --release
cp target/release/cua-driver ~/.local/bin/cua-driver
cua-driver telemetry disable
claude mcp add --scope user --transport stdio cua-driver -- ~/.local/bin/cua-driver mcp --direct
```

Codex: add to `~/.codex/config.toml` (back the file up first):

```toml
[mcp_servers.cua-driver]
command = "/Users/<you>/.local/bin/cua-driver"
args = ["mcp", "--direct"]
```

`--direct` makes the MCP process own its runtime; macOS attributes
Accessibility and Screen Recording to the terminal that spawns the agent, so
grant both to that terminal (System Settings → Privacy & Security) and restart
it. `cua-driver doctor` and the MCP tool `check_permissions` confirm the
state. Sessions started from a GUI client (not a terminal) need the grants on
that client instead. The last verified release is `cua-driver-rs-v0.28.1`
(2026-09-15); newer tags may rename tools, so re-run `cua-driver list-tools`.

## Method: snapshot, act, verify

1. Launch or find the app: `launch_app({bundle_id})` starts it in the
   background; `list_windows({pid})` gives window ids and bounds. A helper
   that prints the on-screen window id and frame (for example a small Swift
   `CGWindowList` tool) is worth keeping in the project.
2. `get_window_state({pid, window_id})` returns the Accessibility tree with
   `element_token`, role, label, value and `frame` (screen points) for every
   element, plus a screenshot. Re-snapshot after every action: tokens are
   scoped to one snapshot and one driver session, and a re-rendered UI makes
   old tokens fail closed.
3. Act by token: `click`, `double_click`, `press_key({pid, window_id, key})`,
   `set_value`. These are Accessibility actions and need no activation; they
   work on windows behind other windows. Verify the effect from the next
   snapshot, never from the driver's `effect` field, which is deliberately
   `unverifiable` for web content and can be a false negative.
4. Native dialogs (password prompts, alerts, open panels) are separate windows
   of the same pid: `list_windows` again, snapshot the newest one, `set_value`
   its text field, `click` its button. The driver refuses process-scoped
   keystrokes while two eligible windows exist; address the exact window.

Web content (WKWebView/Tauri, Electron, browsers) has extra rules:

- Text does not reach a web input by token (`type_text` by element, AX
  `set_value`, Cmd+V): WebKit only inserts text when its text-input context
  is active. Use the pixel form `type_text({pid, window_id, x, y, text})`:
  it performs the SkyLight "active without raise" click first, then types.
  Coordinates are window-local screenshot pixels: `((frame.x + frame.w/2) -
  window.x) × screenshot_scale`, same for y. Mixed layouts and non-Latin text
  work. Keys like Return and Escape work by `press_key` with `window_id`.
- A synthetic double-click may count as two single clicks for an app's own
  repeat-click opener; open with Return on the selected item instead.
- The pixel `click` hit-tests to an Accessibility press, not a real pointer
  event: it cannot prove `pointerdown`/focus-out behavior. For that one class
  of check use the real HID fallback below, with the user warned first.

## Rules that keep the user's desktop untouched

- Never `bring_to_front`, `set_window_frame`, toggle `AXMinimized` or use
  `delivery_mode:"foreground"` on the user's machine without asking: each of
  them pops the window in front of the user's work.
- Stage Manager parks inactive windows in the left strip; WindowServer then
  reports a thumbnail-sized frame (about 131×141 at x≈15). Accessibility
  actions still work there, pixel routes do not. Ask the user to put the app
  in the same set as their terminal (Shift-click the thumbnail) or to disable
  Stage Manager for the session; do not fight it from scripts.
- `osascript` System Events is a fallback only: `keystroke` types through
  the current keyboard layout (Latin text under a Cyrillic layout becomes
  garbage), `click at` behaves like an AX press, both require activating the
  app, and keystrokes land in whatever window is frontmost.
- Real HID input (`scripts/hid-input.swift`, `--global`) moves the cursor and
  needs the app frontmost; use it only for pointer-level checks, announce it,
  and keep it to a few events.
- Unlock only throwaway data with throwaway secrets typed from a file the
  user approved; never type the user's real passwords or provider credentials
  and never record any secret in agent files or replies.
- Screenshots and snapshots go to the project's scratch/build subtree; they
  are evidence for development, not a replacement for the owner's own
  acceptance in the application.

## Project integration

Record the transport in the project's rules (which driver, which mode, who
holds the permissions, the throwaway-data rule) and keep thin wrappers in the
agent tooling directory: `scripts/cua-session.py` runs several tools in one
driver session from a shell (`@find:ROLE:LABEL` resolves tokens from the last
snapshot, `@newest_window` from the last window list, `CUA_RAW=1` prints
element frames). Copy it, do not depend on this skill at run time. In a new
Claude Code session the MCP tools appear as `mcp__cua-driver__<tool>`; Codex
loads them from `config.toml` at start.

## Verification checklist for a new app

- `check_permissions` reports both grants; `launch_app` starts the app while
  the terminal stays frontmost.
- A snapshot lists the app's controls; an AX `click` changes state visible in
  the next snapshot.
- A native dialog accepts `set_value` + button click.
- For web UIs: the px `type_text` route lands text in a field (verify by
  reading the value or the resulting state), and `press_key` Return commits.
- The user's frontmost application never changed during the run.
