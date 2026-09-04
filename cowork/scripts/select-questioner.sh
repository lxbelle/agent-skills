#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: select-questioner.sh <agent-id> <session-label> <dispute-entry> [state-file]" >&2
  exit 64
}

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || usage

agent_id=$1
session_label=$2
dispute_entry=$3
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${4:-$script_dir/STATE.md}
state_dir=$(dirname "$state_file")
lock_dir=$state_dir/.STATE.lock

is_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}
list_contains() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}
list_index() {
  printf '%s\n' "$1" | awk -F, -v id="$2" '
    {
      for (i = 1; i <= NF; i++) if ($i == id) { print i - 1; exit }
    }
  '
}

case "$agent_id" in ''|*[!a-z0-9_-]*|[-_]*) usage ;; esac
case "$session_label" in ''|*[!A-Za-z0-9._:-]*) usage ;; esac
case "$dispute_entry" in M*) ;; *) usage ;; esac
is_uint "${dispute_entry#M}" || usage

if [ ! -f "$state_file" ] || [ -L "$state_file" ]; then
  echo "state file is missing or unsafe: $state_file" >&2
  exit 66
fi

tmp_file=
lock_acquired=0
cleanup() {
  [ -z "$tmp_file" ] || rm -f "$tmp_file"
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
(
  umask 077
  printf 'Agent: %s\nSession: %s\nPID: %s\nAcquired: %s\n' \
    "$agent_id" "$session_label" "$$" "$lock_timestamp" >"$lock_dir/owner"
) || exit 73

read_field() {
  awk -v key="$1" 'index($0, key ": ") == 1 {
    print substr($0, length(key) + 3)
    exit
  }' "$state_file"
}

protocol_version=$(read_field Protocol-version)
status=$(read_field Status)
turn=$(read_field Turn)
lease=$(read_field Lease)
round=$(read_field Round)
agents=$(read_field Agents)
manager=$(read_field Manager)
order=$(read_field Order)
turn_timeout=$(read_field Turn-timeout-seconds)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
   [ -z "$lease" ] || [ -z "$round" ] || [ -z "$agents" ] ||
   [ -z "$manager" ] || [ -z "$order" ] || [ -z "$turn_timeout" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
is_uint "$round" && is_uint "$turn_timeout" || exit 65
"$script_dir/validate-state.sh" "$state_file" >/dev/null
if [ "$status" != WORKING ] || [ "$turn" != "$agent_id" ]; then
  echo "RETRY status=$status turn=$turn lease=$lease" >&2
  exit 75
fi
case "$lease" in
  "$agent_id/$session_label/claim/"*) ;;
  *) echo "RETRY reason=lease-mismatch lease=$lease" >&2; exit 75 ;;
esac

if [ "$manager" != none ]; then
  list_contains "$agents" "$manager" || exit 65
  candidates=$manager
else
  candidates=
  old_ifs=$IFS
  IFS=,
  for candidate in $agents; do
    provider=$(read_field "Provider-$candidate")
    authority=$(read_field "Authority-$candidate")
    case "$provider/$authority" in
      codex/decision|claude/decision)
        if [ -z "$candidates" ]; then
          candidates=$candidate
        else
          candidates=$candidates,$candidate
        fi
        ;;
    esac
  done
  IFS=$old_ifs
  [ -n "$candidates" ] || candidates=$agents
fi

candidate_count=$(printf '%s\n' "$candidates" | awk -F, '{ print NF }')
[ "$candidate_count" -gt 0 ] || exit 65
random_value=
if [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
  random_value=$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | awk 'NF { print $1; exit }')
fi
if ! is_uint "$random_value"; then
  random_value=$(date '+%s')
  random_value=$((random_value + $$))
fi
selected_index=$((random_value % candidate_count))
questioner=$(printf '%s\n' "$candidates" | awk -F, -v field=$((selected_index + 1)) '{ print $field }')
list_contains "$agents" "$questioner" || exit 65

timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
new_status=$status
new_turn=$turn
new_session=$(read_field Turn-session)
new_lease=$lease
new_round=$round
new_deadline=$(read_field Turn-deadline)
new_index=$(list_index "$order" "$turn")
[ -n "$new_session" ] && [ -n "$new_deadline" ] && [ -n "$new_index" ] || exit 65

if [ "$questioner" != "$agent_id" ]; then
  new_status=READY
  new_turn=$questioner
  new_session=$(read_field "Session-$questioner")
  new_lease=none
  new_round=$((round + 1))
  new_index=$(list_index "$order" "$questioner")
  [ -n "$new_session" ] && [ -n "$new_index" ] || exit 65
  now_epoch=$(date '+%s')
  if [ "$turn_timeout" -eq 0 ]; then
    new_deadline=0
  else
    new_deadline=$((now_epoch + turn_timeout))
  fi
fi

tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
cp -p "$state_file" "$tmp_file"
awk -v status="$new_status" -v turn="$new_turn" -v session="$new_session" \
    -v round="$new_round" -v lease="$new_lease" -v updated="$timestamp" \
    -v entry="$dispute_entry" -v questioner="$questioner" \
    -v order_pos="$new_index" -v deadline="$new_deadline" '
  index($0, "Status: ") == 1 { print "Status: " status; next }
  index($0, "Turn: ") == 1 { print "Turn: " turn; next }
  index($0, "Turn-session: ") == 1 { print "Turn-session: " session; next }
  index($0, "Round: ") == 1 { print "Round: " round; next }
  index($0, "Lease: ") == 1 { print "Lease: " lease; next }
  index($0, "Updated: ") == 1 { print "Updated: " updated; next }
  index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
  index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
  index($0, "Turn-deadline: ") == 1 { print "Turn-deadline: " deadline; next }
  index($0, "Questioner: ") == 1 { print "Questioner: " questioner; next }
  index($0, "Dispute-entry: ") == 1 { print "Dispute-entry: " entry; next }
  { print }
' "$state_file" >"$tmp_file"
"$script_dir/validate-state.sh" "$tmp_file" >/dev/null
mv "$tmp_file" "$state_file"
tmp_file=

if [ "$(read_field Questioner)" != "$questioner" ] ||
   [ "$(read_field Dispute-entry)" != "$dispute_entry" ]; then
  echo "RETRY reason=questioner-readback-mismatch" >&2
  exit 75
fi

echo "QUESTIONER agent=$questioner status=$new_status turn=$new_turn"
