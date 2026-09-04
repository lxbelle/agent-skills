#!/bin/sh
set -eu

usage() {
  echo "usage: claim-turn.sh <agent-id> <session-label> [state-file]" >&2
  echo "agent-id: lowercase letters, digits, underscores, hyphens; starts alphanumeric" >&2
  echo "session-label: letters, digits, dots, underscores, colons, hyphens" >&2
  exit 64
}

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage

agent_id=$1
session_label=$2
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${3:-$script_dir/STATE.md}
state_dir=$(dirname "$state_file")
lock_dir=$state_dir/.STATE.lock

case "$agent_id" in
  ''|*[!a-z0-9_-]*|[-_]*) usage ;;
esac
case "$session_label" in
  ''|*[!A-Za-z0-9._:-]*) usage ;;
esac

if [ ! -f "$state_file" ] || [ -L "$state_file" ]; then
  echo "state file is missing or unsafe: $state_file" >&2
  exit 66
fi

tmp_file=
lock_acquired=0
cleanup() {
  if [ -n "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
  if [ "$lock_acquired" -eq 1 ]; then
    rm -f "$lock_dir/owner"
    rmdir "$lock_dir" 2>/dev/null || true
  fi
}
trap cleanup 0
trap 'exit 130' HUP INT TERM

if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "RETRY reason=state-lock-busy owner-record=$lock_dir/owner" >&2
  exit 75
fi
lock_acquired=1

lock_timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
if ! (
  umask 077
  printf 'Agent: %s\nSession: %s\nPID: %s\nAcquired: %s\n' \
    "$agent_id" "$session_label" "$$" "$lock_timestamp" >"$lock_dir/owner"
); then
  echo "cannot record state-lock owner: $lock_dir/owner" >&2
  exit 73
fi

read_field() {
  awk -v key="$1" 'index($0, key ": ") == 1 {
    print substr($0, length(key) + 3)
    exit
  }' "$state_file"
}

protocol_version=$(read_field Protocol-version)
status=$(read_field Status)
turn=$(read_field Turn)
turn_session=$(read_field Turn-session)
agents=$(read_field Agents)
lease_before=$(read_field Lease)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
   [ -z "$turn_session" ] || [ -z "$agents" ] || [ -z "$lease_before" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
"$script_dir/validate-state.sh" "$state_file" >/dev/null

case ",$agents," in
  *",$agent_id,"*) ;;
  *)
    echo "agent is not registered in Agents: $agent_id" >&2
    exit 64
    ;;
esac

if [ "$status" != READY ] || [ "$turn" != "$agent_id" ] ||
   [ "$lease_before" != none ]; then
  echo "RETRY status=$status turn=$turn lease=$lease_before" >&2
  exit 75
fi
if [ "$turn_session" != any ] && [ "$turn_session" != "$session_label" ]; then
  echo "OTHER_SESSION agent=$agent_id expected=$turn_session" >&2
  exit 76
fi

timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
lease="$agent_id/$session_label/claim/$timestamp/$$"
tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
cp -p "$state_file" "$tmp_file"

awk -v lease="$lease" -v updated="$timestamp" '
  index($0, "Status: ") == 1 { print "Status: WORKING"; next }
  index($0, "Lease: ") == 1 { print "Lease: " lease; next }
  index($0, "Updated: ") == 1 { print "Updated: " updated; next }
  { print }
' "$state_file" >"$tmp_file"

"$script_dir/validate-state.sh" "$tmp_file" >/dev/null
mv "$tmp_file" "$state_file"
tmp_file=

lease_after=$(read_field Lease)
status_after=$(read_field Status)
if [ "$lease_after" != "$lease" ] || [ "$status_after" != WORKING ]; then
  echo "RETRY reason=claim-readback-mismatch" >&2
  exit 75
fi

echo "CLAIMED agent=$agent_id session=$session_label lease=$lease"
