#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: advance-turn.sh <handoff|skip> <agent-id> <session-label> <next-agent|auto> <chat-entry> [state-file]" >&2
  exit 64
}

[ "$#" -ge 5 ] && [ "$#" -le 6 ] || usage

operation=$1
agent_id=$2
session_label=$3
next_requested=$4
chat_entry=$5
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${6:-$script_dir/STATE.md}
state_dir=$(dirname "$state_file")
lock_dir=$state_dir/.STATE.lock

case "$operation" in handoff|skip) ;; *) usage ;; esac
case "$agent_id" in ''|*[!a-z0-9_-]*|[-_]*) usage ;; esac
case "$session_label" in ''|*[!A-Za-z0-9._:-]*) usage ;; esac
case "$next_requested" in
  auto) ;;
  ''|*[!a-z0-9_-]*|[-_]*) usage ;;
esac
is_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

case "$chat_entry" in M*) ;; *) usage ;; esac
entry_number=${chat_entry#M}
is_uint "$entry_number" || usage

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
turn_session=$(read_field Turn-session)
round=$(read_field Round)
lease=$(read_field Lease)
agents=$(read_field Agents)
coordinator=$(read_field Coordinator)
order_policy=$(read_field Order-policy)
order=$(read_field Order)
order_index=$(read_field Order-index)
turn_timeout=$(read_field Turn-timeout-seconds)
turn_deadline=$(read_field Turn-deadline)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
   [ -z "$turn_session" ] || [ -z "$round" ] || [ -z "$lease" ] ||
   [ -z "$agents" ] || [ -z "$coordinator" ] || [ -z "$order_policy" ] ||
   [ -z "$order" ] || [ -z "$order_index" ] || [ -z "$turn_timeout" ] ||
   [ -z "$turn_deadline" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
is_uint "$round" && is_uint "$order_index" && is_uint "$turn_timeout" &&
  is_uint "$turn_deadline" || {
    echo "state has invalid numeric fields: $state_file" >&2
    exit 65
  }
"$script_dir/validate-state.sh" "$state_file" >/dev/null

case ",$agents," in *",$agent_id,"*) ;; *) usage ;; esac

case "$operation" in
  handoff)
    case "$lease" in
      "$agent_id/$session_label/claim/"*) ;;
      *)
        echo "RETRY status=$status turn=$turn lease=$lease" >&2
        exit 75
        ;;
    esac
    if [ "$status" != WORKING ] || [ "$turn" != "$agent_id" ]; then
      echo "RETRY status=$status turn=$turn lease=$lease" >&2
      exit 75
    fi
    ;;
  skip)
    coordinator_session=$(read_field "Session-$coordinator")
    if [ "$agent_id" != "$coordinator" ] || [ "$status" != READY ] ||
       [ "$lease" != none ] || [ -z "$coordinator_session" ]; then
      echo "RETRY status=$status turn=$turn lease=$lease" >&2
      exit 75
    fi
    if [ "$coordinator_session" != any ] &&
       [ "$coordinator_session" != "$session_label" ]; then
      echo "OTHER_SESSION agent=$agent_id expected=$coordinator_session" >&2
      exit 76
    fi
    now_epoch=$(date '+%s')
    if [ "$turn_deadline" -eq 0 ] || [ "$now_epoch" -lt "$turn_deadline" ]; then
      echo "RETRY reason=turn-deadline-not-reached deadline=$turn_deadline" >&2
      exit 75
    fi
    ;;
esac

case "$order_policy" in
  queue)
    [ "$next_requested" != auto ] || usage
    next_agent=$next_requested
    ;;
  round-robin)
    [ "$next_requested" = auto ] || usage
    order_count=$(printf '%s\n' "$order" | awk -F, '{ print NF }')
    [ "$order_count" -gt 0 ] && [ "$order_index" -lt "$order_count" ] || exit 65
    new_index=$(((order_index + 1) % order_count))
    next_agent=$(printf '%s\n' "$order" | awk -F, -v field=$((new_index + 1)) '{ print $field }')
    ;;
  *)
    echo "invalid order policy: $order_policy" >&2
    exit 65
    ;;
esac

case ",$agents," in *",$next_agent,"*) ;; *) usage ;; esac
next_session=$(read_field "Session-$next_agent")
[ -n "$next_session" ] || exit 65

if [ "$order_policy" = queue ]; then
  new_index=$(printf '%s\n' "$order" | awk -F, -v id="$next_agent" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == id) {
          print i - 1
          exit
        }
      }
    }
  ')
  [ -n "$new_index" ] || exit 65
fi

now_epoch=$(date '+%s')
if [ "$turn_timeout" -eq 0 ]; then
  new_deadline=0
else
  new_deadline=$((now_epoch + turn_timeout))
fi
new_round=$((round + 1))
timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
cp -p "$state_file" "$tmp_file"

awk -v status=READY -v turn="$next_agent" -v session="$next_session" \
    -v round="$new_round" -v updated="$timestamp" -v entry="$chat_entry" \
    -v order_pos="$new_index" -v deadline="$new_deadline" '
  index($0, "Status: ") == 1 { print "Status: " status; next }
  index($0, "Turn: ") == 1 { print "Turn: " turn; next }
  index($0, "Turn-session: ") == 1 { print "Turn-session: " session; next }
  index($0, "Round: ") == 1 { print "Round: " round; next }
  index($0, "Lease: ") == 1 { print "Lease: none"; next }
  index($0, "Updated: ") == 1 { print "Updated: " updated; next }
  index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
  index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
  index($0, "Turn-deadline: ") == 1 { print "Turn-deadline: " deadline; next }
  { print }
' "$state_file" >"$tmp_file"

"$script_dir/validate-state.sh" "$tmp_file" >/dev/null
mv "$tmp_file" "$state_file"
tmp_file=

status_after=$(read_field Status)
turn_after=$(read_field Turn)
lease_after=$(read_field Lease)
entry_after=$(read_field Last-entry)
if [ "$status_after" != READY ] || [ "$turn_after" != "$next_agent" ] ||
   [ "$lease_after" != none ] || [ "$entry_after" != "$chat_entry" ]; then
  echo "RETRY reason=advance-readback-mismatch" >&2
  exit 75
fi

echo "READY turn=$next_agent session=$next_session round=$new_round deadline=$new_deadline"
