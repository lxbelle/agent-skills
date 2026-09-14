#!/bin/sh
# Reference launcher for one Codex command-line worker round (Startup skill,
# "Command-line workers"). Copy to <project>/.agents/bin/codex-worker.sh when a
# project selects this transport. Project-independent: the root is derived from
# this file's location, roles from .agents/roles/<role>.md, the reading route
# from the root AGENTS.md chain that Codex loads itself.
#
# Usage:
#   codex-worker.sh <TASK-ID> <round> <role> <read-only|workspace-write> <dispatch-token>
#                   [--resume <thread-id> <amendment-file>] [--print]
#
# Roles: `reviewer` writes Review; any other role writes Checkpoint/Handoff and
# chains .agents/roles/developer.md first unless it is `developer` itself. A role
# file containing the line `Dispatch: claude-only` (or `Dispatch: manual`) is
# refused here. Output lands under target/agents/runs/<TASK-ID>-r<round>/:
# prompt.md, events.jsonl, last.md, stderr.log, thread_id. The script prints
# only the run directory, thread id, exit code and usage; never the transcript.
set -eu

usage() { sed -n '9,11p' "$0" >&2; exit 2; }
[ $# -ge 5 ] || usage
task_id="$1"; round="$2"; role="$3"; sandbox="$4"; token="$5"; shift 5
resume_thread=""; amendment_file=""; print_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --resume) [ $# -ge 3 ] || usage; resume_thread="$2"; amendment_file="$3"; shift 3 ;;
    --print) print_only=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
root="$(cd "$script_dir/../.." && pwd -P)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
[ "$git_root" = "$root" ] || { echo "Launcher must live at <repo>/.agents/bin/; resolved root: $root" >&2; exit 2; }
[ -f "$root/AGENTS.md" ] || { echo "Missing $root/AGENTS.md" >&2; exit 2; }
packet=".agents/tasks/$task_id.md"
[ -f "$root/$packet" ] || { echo "Missing packet $packet" >&2; exit 2; }
case "$sandbox" in read-only|workspace-write) ;; *) echo "Sandbox must be read-only or workspace-write" >&2; exit 2 ;; esac
case "$role" in */*|.*) echo "Invalid role name" >&2; exit 2 ;; esac
role_file=".agents/roles/$role.md"
[ -f "$root/$role_file" ] || { echo "Missing role file $role_file" >&2; exit 2; }
if grep -qE '^Dispatch: (claude-only|manual)' "$root/$role_file"; then
  echo "Role $role is not dispatchable through this launcher (see $role_file)" >&2; exit 2
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

if [ -n "$resume_thread" ]; then
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
1. The root AGENTS.md (your client loads it) and everything it names as required
   reading. Only if your packet's Writable paths name product directories, also
   read the nearest scope AGENTS.md/README for those directories.
2. Role chain: $role_files
3. Your canonical task packet: $packet
4. Only the packet's "Inputs to read".
Do not read .agents/STATE.md, .agents/ROADMAP.md, other tasks, .agents/history
or .agents/prompts. Do not scan the private tree.

Claim: round $round, dispatch token $token. Verify the packet header names this
round and token and that no other run holds it; otherwise stop and report. Then
set Status: $claim, Writer run: \`codex exec $token\` (the manager records your
thread id), and Updated with a timezone-bearing timestamp.

This run is one turn: nobody can message you and you cannot ask. Put questions,
blockers and required manager actions into your $sections section and yield.
Work only inside the packet's Writable paths and Command authority; your sandbox
is $sandbox. Build/test/temporary output goes only below target/agents/. Never
commit, push, install, contact the network outside authorized commands, store
secrets, launch applications, touch removable media or user data, or edit paths
outside your ownership. Observe every check's output before claiming it.

Finish by writing your $sections in the packet, then reply with a final message
of at most 40 lines: status, changed paths, checks run with observed results,
blockers, explicit yield. Timestamps: use \`date '+%Y-%m-%dT%H:%M:%S%z'\`.
PROMPT
fi

if [ -n "$resume_thread" ]; then
  set -- codex exec resume "$resume_thread" -C "$root" -s "$sandbox" --json -o "$last" -
else
  set -- codex exec -C "$root" -s "$sandbox" --json -o "$last" -
fi

if [ "$print_only" -eq 1 ]; then
  echo "Run directory: $run_dir"; echo "Command: $* < $prompt"; echo "--- prompt ---"; cat "$prompt"; exit 0
fi

set +e
"$@" < "$prompt" > "$events" 2> "$errlog"
code=$?
set -e
thread="$(grep -m1 -o '"thread_id":"[^"]*"' "$events" 2>/dev/null | cut -d'"' -f4 || true)"
[ -n "$thread" ] && echo "$thread" > "$run_dir/thread_id"
usage_line="$(grep -o '"usage":{[^}]*}' "$events" 2>/dev/null | tail -1 || true)"
echo "Run directory: $run_dir"
echo "Thread id: ${thread:-unknown}   Exit code: $code"
echo "Usage: ${usage_line:-unknown}"
echo "Final message: $last ($(wc -l < "$last" 2>/dev/null || echo 0) lines)"
[ -s "$errlog" ] && echo "Stderr: $errlog ($(wc -l < "$errlog") lines)"
exit "$code"
