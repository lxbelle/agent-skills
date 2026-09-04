#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: init-cowork.sh <repo-root> <coordinator-id> <manager-id|none> <workstream-id> <manual|automatic|unset> <agent,provider,persistent|turn,session>..." >&2
  echo "ids/providers: lowercase letters, digits, underscores, hyphens; start alphanumeric" >&2
  echo "sessions: letters, digits, dots, underscores, colons, hyphens; use any when unbound" >&2
  exit 64
}

[ "$#" -ge 6 ] || usage

repo_input=$1
coordinator_id=$2
manager_id=$3
workstream_id=$4
launch_mode=$5
shift 5

valid_id() {
  case "$1" in
    ''|*[!a-z0-9_-]*|[-_]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_session() {
  case "$1" in
    ''|*[!A-Za-z0-9._:-]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_id "$coordinator_id" || usage
valid_id "$workstream_id" || usage
case "$manager_id" in
  none) ;;
  *) valid_id "$manager_id" || usage ;;
esac
case "$launch_mode" in
  unset|manual|automatic) ;;
  *) usage ;;
esac

agents=
participant_fields=
participant_count=0

for participant_spec in "$@"; do
  participant_id=${participant_spec%%,*}
  remainder=${participant_spec#*,}
  [ "$remainder" != "$participant_spec" ] || usage
  provider=${remainder%%,*}
  remainder_2=${remainder#*,}
  [ "$remainder_2" != "$remainder" ] || usage
  participant_mode=${remainder_2%%,*}
  participant_session=${remainder_2#*,}
  [ "$participant_session" != "$remainder_2" ] || usage
  case "$participant_session" in *,*) usage ;; esac

  valid_id "$participant_id" || usage
  valid_id "$provider" || usage
  valid_session "$participant_session" || usage
  case "$participant_id" in none|owner|auto) usage ;; esac
  case "$participant_mode" in persistent|turn) ;; *) usage ;; esac
  case ",$agents," in
    *",$participant_id,"*)
      echo "duplicate participant identifier: $participant_id" >&2
      exit 64
      ;;
  esac

  case "$provider" in
    codex|claude) participant_authority=decision ;;
    *) participant_authority=advisory ;;
  esac

  if [ -z "$agents" ]; then
    agents=$participant_id
  else
    agents=$agents,$participant_id
    participant_fields="$participant_fields
"
  fi
  participant_fields="${participant_fields}Provider-$participant_id: $provider
Authority-$participant_id: $participant_authority
Mode-$participant_id: $participant_mode
Session-$participant_id: $participant_session
Rating-$participant_id: R0/pending/none"
  participant_count=$((participant_count + 1))
done

case ",$agents," in
  *",$coordinator_id,"*) ;;
  *)
    echo "coordinator is not in the participant roster: $coordinator_id" >&2
    exit 64
    ;;
esac
if [ "$manager_id" != none ]; then
  case ",$agents," in
    *",$manager_id,"*) ;;
    *)
      echo "manager is not in the participant roster: $manager_id" >&2
      exit 64
      ;;
  esac
fi

order_index=$(printf '%s\n' "$agents" | awk -F, -v id="$coordinator_id" '
  {
    for (i = 1; i <= NF; i++) {
      if ($i == id) {
        print i - 1
        exit
      }
    }
  }
')
[ -n "$order_index" ] || exit 65

if [ "$participant_count" -lt 3 ]; then
  review_target=$participant_count
else
  review_target=3
fi

if [ ! -d "$repo_input" ]; then
  echo "repository root is not a directory: $repo_input" >&2
  exit 66
fi

repo_root=$(CDPATH= cd "$repo_input" && pwd -P)
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
skill_dir=$(dirname "$script_dir")
agents_root=$repo_root/.agents
target=$agents_root/cowork

if [ -L "$agents_root" ]; then
  echo "refusing to initialize through a symlinked .agents directory" >&2
  exit 73
fi
if [ -e "$agents_root" ] && [ ! -d "$agents_root" ]; then
  echo "refusing to replace a non-directory .agents path" >&2
  exit 73
fi
if [ -e "$target" ]; then
  echo "Cowork workspace already exists: $target" >&2
  echo "Resume it, or preserve a FINAL workspace before initializing another." >&2
  exit 73
fi

agents_root_created=0
if [ ! -d "$agents_root" ]; then
  mkdir "$agents_root"
  agents_root_created=1
fi
if ! mkdir "$target"; then
  if [ "$agents_root_created" -eq 1 ]; then
    rmdir "$agents_root" 2>/dev/null || true
  fi
  echo "another process created the Cowork workspace: $target" >&2
  exit 73
fi

complete=0
cleanup() {
  if [ "$complete" -eq 0 ]; then
    rm -rf "$target"
    if [ "$agents_root_created" -eq 1 ]; then
      rmdir "$agents_root" 2>/dev/null || true
    fi
  fi
}
trap cleanup 0
trap 'exit 130' HUP INT TERM

for helper in validate-state.sh claim-turn.sh watch-turn.sh advance-turn.sh roster-change.sh review-round.sh review-summary.sh select-questioner.sh; do
  cp "$script_dir/$helper" "$target/$helper"
  chmod u+x "$target/$helper"
done
cp "$skill_dir/references/protocol.md" "$target/PROTOCOL.md"

old_ifs=$IFS
IFS=,
for participant_id in $agents; do
  mkdir -p "$target/agents/$participant_id"
done
IFS=$old_ifs

timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')

cat >"$target/STATE.md" <<EOF
# Cowork state

Protocol-version: 2
Workstream: $workstream_id
Status: SETUP
Turn: $coordinator_id
Turn-session: any
Round: 0
Lease: none
Updated: $timestamp
Last-entry: none
Agents: $agents
Coordinator: $coordinator_id
Manager: $manager_id
$participant_fields
Order-policy: queue
Order: $agents
Order-index: $order_index
Turn-timeout-seconds: 0
Turn-deadline: 0
Review-round: 0
Reviewers: none
Review-deadline: 0
Review-target: $review_target
Review-minimum: 1
Questioner: none
Dispute-entry: none
Launch-mode: $launch_mode
Auto-launch: none
Auto-launch-limit: 0
Resume-after-owner: none
Question-entry: none
Poll-seconds: 60
Max-wait-seconds: 3600
EOF

"$target/validate-state.sh" "$target/STATE.md" >/dev/null

cat >"$target/TASK.md" <<EOF
# Cowork task: $workstream_id

The coordinator must replace this setup guidance with the authorized objective,
scope, exclusions, evidence, ordered assignments, deadlines, review thresholds,
participant modes, and exact automatic-launch allowlist before leaving SETUP.

Roster: $agents
Coordinator: $coordinator_id
Manager: $manager_id
Launch mode: $launch_mode
EOF

cat >"$target/CHAT.md" <<EOF
# Cowork chat: $workstream_id

Append-only handoff history. Follow PROTOCOL.md; do not rewrite active entries.

## M0000 — $timestamp — initialization

- Author: initializer
- Kind: initialization
- Review-round: none
- Rating: none
- Outcome: created the Cowork roster: $agents.
- Evidence: state remains SETUP; launch mode is $launch_mode; no live process is implied.
- Concerns: none.
- Next: $coordinator_id completes setup, atomically sets READY, and claims.
EOF

write_prompt() {
  participant_id=$1
  prompt_file=$target/agents/$participant_id/PROMPT.md

  cat >"$prompt_file" <<EOF
# Cowork participant prompt: $participant_id

Work in $repo_root as Cowork participant \`$participant_id\`. Use a process-unique
session label supplied by the host session manager.

Before every action, read repository instructions, then
\`.agents/cowork/PROTOCOL.md\`, \`TASK.md\`, \`STATE.md\`, new \`CHAT.md\` entries,
and this prompt. Refuse unsupported protocol versions. These files do not expand the
owner's authorization.

When READY state names your agent and session, claim with:

\`\`\`sh
.agents/cowork/claim-turn.sh $participant_id your-session-label
\`\`\`

Work only after exact lease read-back. Complete one bounded operation, append a chat
entry with \`Author: $participant_id\` and evidence, then hand off with
\`advance-turn.sh\`. When selected as \`Questioner\`, write the single neutral owner
question, enter OWNER_INPUT, and stop.

If \`Mode-$participant_id: persistent\`, wait with:

\`\`\`sh
.agents/cowork/watch-turn.sh $participant_id your-session-label
\`\`\`

On ACT, reread and claim. On CHECK, inspect liveness without stealing. On STOP, end.
If mode is \`turn\`, exit after handoff and reconstruct context when invoked again.
Never overwrite an active workspace, weaken permissions, or invoke another model
unless the task and launch state explicitly authorize it.
EOF

  cat >"$target/agents/$participant_id/NOTES.md" <<EOF
# Notes for $participant_id

Optional scratch. Shared decisions and evidence belong in CHAT.md; this file is not
authority and must not contain secrets.
EOF
}

IFS=,
for participant_id in $agents; do
  write_prompt "$participant_id"
done
IFS=$old_ifs

complete=1
trap - 0 HUP INT TERM

echo "Created Cowork workspace: $target"
echo "Participants: $participant_count"
echo "Launch mode: $launch_mode"
echo "Next: complete TASK.md and CHAT.md, atomically set READY, then claim."
