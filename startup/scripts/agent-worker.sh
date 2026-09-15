#!/bin/sh
# Reference launcher for one command-line worker round (Startup skill,
# "Command-line workers"). Copy unchanged to <project>/.agents/bin/agent-worker.sh
# when a project selects this transport. Project-independent: the root comes from
# this file's location, roles from .agents/roles/<role>.md, and the reading route
# from the root AGENTS.md chain that the worker's client loads itself.
#
# Usage:
#   agent-worker.sh <client> <TASK-ID> <round> <role> <read-only|workspace-write> <dispatch-token>
#                   [--resume <run-id> <amendment-file>] [--print]
#
# Clients: codex (codex exec), claude (claude -p). Add another client by adding one
# case to build_command() and one to extract_identity(); do not change the prompt.
# Roles: `reviewer` writes Review; any other role writes Checkpoint/Handoff and
# chains .agents/roles/developer.md first unless it is `developer`. A role file
# carrying `Dispatch: <client>-only` runs only on that client; `Dispatch: manual`
# is never launched here. Output lands under target/agents/runs/<TASK-ID>-r<round>/:
# prompt.md, events.jsonl (raw client output), last.md (final message), stderr.log,
# thread_id. Only the run directory, run id, exit code and usage are printed; the
# transcript never reaches the manager's context. Optional env: WORKER_MODEL, WORKER_EFFORT.
set -eu

usage() { sed -n '9,10p' "$0" >&2; exit 2; }
[ $# -ge 6 ] || usage
client="$1"; task_id="$2"; round="$3"; role="$4"; sandbox="$5"; token="$6"; shift 6
resume_id=""; amendment_file=""; print_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) [ $# -ge 3 ] || usage; resume_id="$2"; amendment_file="$3"; shift 3 ;;
    --print) print_only=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$client" in codex|claude) ;; *) echo "Client '$client' is not configured in this launcher (codex, claude). Add it to build_command/extract_identity." >&2; exit 2 ;; esac
command -v "$client" >/dev/null 2>&1 || { echo "Client binary '$client' not found in PATH" >&2; exit 2; }

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
root="$(cd "$script_dir/../.." && pwd -P)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
[ "$git_root" = "$root" ] || { echo "Launcher must live at <repo>/.agents/bin/; resolved root: $root" >&2; exit 2; }
[ -f "$root/AGENTS.md" ] || { echo "Missing $root/AGENTS.md" >&2; exit 2; }
packet=".agents/tasks/$task_id.md"
[ -f "$root/$packet" ] || { echo "Missing packet $packet" >&2; exit 2; }
case "$sandbox" in read-only|workspace-write) ;; *) echo "Sandbox must be read-only or workspace-write" >&2; exit 2 ;; esac
case "$role" in */*|.*|"") echo "Invalid role name" >&2; exit 2 ;; esac
role_file=".agents/roles/$role.md"
[ -f "$root/$role_file" ] || { echo "Missing role file $role_file" >&2; exit 2; }
if grep -qE '^Dispatch: manual' "$root/$role_file"; then
  echo "Role $role is manual-launch only (see $role_file)" >&2; exit 2
fi
only="$(grep -oE '^Dispatch: [a-z]+-only' "$root/$role_file" | head -1 | sed -E 's/^Dispatch: ([a-z]+)-only/\1/' || true)"
if [ -n "$only" ] && [ "$only" != "$client" ]; then
  echo "Role $role is dispatchable only on client '$only' (see $role_file)" >&2; exit 2
fi
case "$role" in
  reviewer)  role_title="independent reviewer"; role_files="$role_file"; claim="Review"; sections="Review" ;;
  developer) role_title="developer (executor)"; role_files="$role_file"; claim="Active"; sections="Checkpoint and Handoff" ;;
  *)         role_title="$role (executor specialization)"; role_files=".agents/roles/developer.md, then $role_file"; claim="Active"; sections="Checkpoint and Handoff" ;;
esac

[ ! -L "$root/target" ] && [ ! -L "$root/target/agents" ] || { echo "target or target/agents is a symlink" >&2; exit 2; }
run_dir="$root/target/agents/runs/${task_id}-r${round}"
mkdir -p "$run_dir"
prompt="$run_dir/prompt.md"; events="$run_dir/events.jsonl"; last="$run_dir/last.md"; errlog="$run_dir/stderr.log"

if [ -n "$resume_id" ]; then
  [ -r "$amendment_file" ] || { echo "Amendment file unreadable: $amendment_file" >&2; exit 2; }
  {
    echo "Manager amendment for task $task_id, round $round, dispatch token $token."
    echo "You remain the assigned $role_title for this packet; nothing else about your role, scope or authority changed unless stated below. Record this amendment compactly and attributed in your own packet section, act on it within Writable paths and Command authority, then update your $sections and reply with a final message of at most 40 lines: status, changed paths, checks run with observed results, blockers, explicit yield."
    echo
    cat "$amendment_file"
  } > "$prompt"
else
  cat > "$prompt" <<PROMPT
You are the assigned $role_title for this repository, launched as a
non-interactive command-line worker by the engineering manager. You are not the
manager. Execution and coordination root: $root (your working directory).

Read in this order and nothing else:
1. The root AGENTS.md (your client loads it or its project file that imports
   it) and everything it names as required reading. Only if your packet's
   Writable paths name product directories, also read the nearest scope
   AGENTS.md/README for those directories.
2. Role chain: $role_files
3. Your canonical task packet: $packet
4. Only the packet's "Inputs to read".
Do not read .agents/STATE.md, .agents/ROADMAP.md, other tasks, .agents/history
or .agents/prompts. Do not scan the private tree.

Claim: round $round, dispatch token $token. Verify the packet header names this
round and token and that no other run holds it; otherwise stop and report. Then
set Status: $claim, Writer run: \`$client $token\` (the manager records your
run id), and Updated with a timezone-bearing timestamp.

This run is one turn: nobody can message you and you cannot ask. Put questions,
blockers and required manager actions into your $sections section and yield.
Work only inside the packet's Writable paths and Command authority; your access
level is $sandbox. Build/test/temporary output goes only below target/agents/.
Never commit, push, install, contact the network outside authorized commands,
store secrets, launch applications, touch removable media or user data, or edit
paths outside your ownership. Observe every check's output before claiming it.

Finish by writing your $sections in the packet, then reply with a final message
of at most 40 lines: status, changed paths, checks run with observed results,
blockers, explicit yield. Timestamps: use \`date '+%Y-%m-%dT%H:%M:%S%z'\`.
PROMPT
fi

# Per-client command. Each client must: run non-interactively, read the prompt
# from $prompt, never open an approval prompt, write raw output to stdout, and
# refuse approval/sandbox bypass flags.
build_command() {
  case "$client" in
    codex)
      # Sandbox is OS-enforced. --json streams events; -o writes the final message.
      # `codex exec resume` accepts neither -C nor -s (codex-cli 0.153): the
      # working directory is this launcher's cd into $root and the sandbox is
      # passed as the equivalent config override.
      if [ -n "$resume_id" ]; then set -- codex exec resume "$resume_id" -c "sandbox_mode=\"$sandbox\""; else set -- codex exec -C "$root" -s "$sandbox"; fi
      [ -z "${WORKER_MODEL:-}" ] || set -- "$@" -m "$WORKER_MODEL"
      # Optional reasoning effort override (low|medium|high|xhigh|max), e.g. WORKER_EFFORT=xhigh.
      [ -z "${WORKER_EFFORT:-}" ] || set -- "$@" -c "model_reasoning_effort=\"$WORKER_EFFORT\""
      set -- "$@" --json -o "$last" -
      printf '%s\n' "$@"
      ;;
    claude)
      # Boundary: permission mode auto (classifier; destructive actions denied,
      # prompts never shown in -p mode, denials listed in permission_denials).
      # read-only additionally removes the editing tools; the manager still
      # verifies the tree, as with any client. Plan mode is deliberately not
      # used: it writes plan files outside the repository.
      if [ "$sandbox" = "read-only" ]; then deny="Edit,Write,NotebookEdit,WebFetch,WebSearch"; else deny="WebFetch,WebSearch"; fi
      # The prompt arrives on stdin (documented pipe usage of -p).
      set -- claude -p --output-format json --permission-mode auto --permission-prompts none \
        --disallowedTools "$deny"
      [ -z "${WORKER_MODEL:-}" ] || set -- "$@" --model "$WORKER_MODEL"
      [ -z "$resume_id" ] || set -- "$@" --resume "$resume_id"
      printf '%s\n' "$@"
      ;;
  esac
  return 0
}

# Per-client identity/usage/final-message extraction from $events.
extract_identity() {
  case "$client" in
    codex)
      thread="$(grep -m1 -o '"thread_id":"[^"]*"' "$events" 2>/dev/null | cut -d'"' -f4 || true)"
      usage_line="$(grep -o '"usage":{[^}]*}' "$events" 2>/dev/null | tail -1 || true)"
      ;;
    claude)
      thread="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("session_id",""))' "$events" 2>/dev/null || true)"
      usage_line="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d.get("usage",{})))' "$events" 2>/dev/null || true)"
      python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));open(sys.argv[2],"w").write(str(d.get("result","")))' "$events" "$last" 2>/dev/null || true
      denials="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(len(d.get("permission_denials",[])))' "$events" 2>/dev/null || echo "?")"
      [ "$denials" = "0" ] || echo "Permission denials: $denials (see $events)"
      ;;
  esac
  return 0
}

if [ "$print_only" -eq 1 ]; then
  echo "Run directory: $run_dir"; echo "Command (one argument per line, prompt on stdin):"; build_command
  echo "--- prompt ---"; cat "$prompt"; exit 0
fi

# Every client reads the prompt from stdin (never left open: a client that sees a
# pipe may otherwise wait forever). Nesting variables are removed so a Claude
# worker can be launched from inside another Claude Code session.
build_command > "$run_dir/.argv"
set +e
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT sh -c '
  set -e; cd "$1"; shift; argv_file="$1"; shift
  set --; while IFS= read -r line; do set -- "$@" "$line"; done < "$argv_file"
  exec "$@"' sh "$root" "$run_dir/.argv" < "$prompt" > "$events" 2> "$errlog"
code=$?
set -e
rm -f "$run_dir/.argv"
thread=""; usage_line=""
extract_identity
[ -z "$thread" ] || echo "$thread" > "$run_dir/thread_id"
echo "Run directory: $run_dir"
echo "Run id: ${thread:-unknown}   Exit code: $code"
echo "Usage: ${usage_line:-unknown}"
echo "Final message: $last ($(wc -l < "$last" 2>/dev/null || echo 0) lines)"
[ ! -s "$errlog" ] || echo "Stderr: $errlog ($(wc -l < "$errlog") lines)"
exit "$code"
