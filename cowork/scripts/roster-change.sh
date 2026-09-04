#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: roster-change.sh <coordinator-id> <session-label> <owner-entry> <add|remove|reorder> <value> [state-file]" >&2
  echo "add value: agent-id,provider,persistent|turn,session" >&2
  exit 64
}

[ "$#" -ge 5 ] && [ "$#" -le 6 ] || usage

agent_id=$1
session_label=$2
owner_entry=$3
operation=$4
value=$5
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${6:-$script_dir/STATE.md}
state_dir=$(dirname "$state_file")
lock_dir=$state_dir/.STATE.lock

valid_id() {
  case "$1" in ''|*[!a-z0-9_-]*|[-_]*) return 1 ;; *) return 0 ;; esac
}
valid_session() {
  case "$1" in ''|*[!A-Za-z0-9._:-]*) return 1 ;; *) return 0 ;; esac
}
is_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}
list_contains() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}
list_index() {
  printf '%s\n' "$1" | awk -F, -v id="$2" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == id) {
          print i - 1
          exit
        }
      }
    }
  '
}
remove_from_list() {
  printf '%s\n' "$1" | awk -F, -v id="$2" '
    {
      out = ""
      for (i = 1; i <= NF; i++) {
        if ($i != id) out = out (out == "" ? "" : ",") $i
      }
      print out
    }
  '
}

valid_id "$agent_id" || usage
valid_session "$session_label" || usage
case "$owner_entry" in M*) ;; *) usage ;; esac
entry_number=${owner_entry#M}
is_uint "$entry_number" || usage
case "$operation" in add|remove|reorder) ;; *) usage ;; esac

if [ ! -f "$state_file" ] || [ -L "$state_file" ]; then
  echo "state file is missing or unsafe: $state_file" >&2
  exit 66
fi

tmp_file=
lock_acquired=0
participant_dir_created=0
participant_dir_keep=0
new_participant_dir=
cleanup() {
  [ -z "$tmp_file" ] || rm -f "$tmp_file"
  if [ "$participant_dir_created" -eq 1 ] && [ "$participant_dir_keep" -eq 0 ]; then
    rm -rf "$new_participant_dir"
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
agents=$(read_field Agents)
coordinator=$(read_field Coordinator)
manager=$(read_field Manager)
order=$(read_field Order)
review_round=$(read_field Review-round)
reviewers=$(read_field Reviewers)
questioner=$(read_field Questioner)
auto_launch=$(read_field Auto-launch)
auto_limit=$(read_field Auto-launch-limit)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
   [ -z "$lease" ] || [ -z "$agents" ] || [ -z "$coordinator" ] ||
   [ -z "$manager" ] || [ -z "$order" ] || [ -z "$review_round" ] ||
   [ -z "$reviewers" ] || [ -z "$questioner" ] || [ -z "$auto_launch" ] ||
   [ -z "$auto_limit" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
is_uint "$review_round" && is_uint "$auto_limit" || exit 65
"$script_dir/validate-state.sh" "$state_file" >/dev/null
if [ "$agent_id" != "$coordinator" ] || [ "$status" != WORKING ] ||
   [ "$turn" != "$agent_id" ] || [ "$reviewers" != none ] ||
   [ "$questioner" != none ]; then
  echo "RETRY reason=roster-change-boundary status=$status turn=$turn reviewers=$reviewers questioner=$questioner" >&2
  exit 75
fi
case "$lease" in
  "$agent_id/$session_label/claim/"*) ;;
  *)
    echo "RETRY reason=lease-mismatch lease=$lease" >&2
    exit 75
    ;;
esac

new_agents=$agents
new_order=$order
new_manager=$manager
new_auto_launch=$auto_launch
new_auto_limit=$auto_limit
add_id=
remove_id=

case "$operation" in
  add)
    add_id=${value%%,*}
    remainder=${value#*,}
    [ "$remainder" != "$value" ] || usage
    add_provider=${remainder%%,*}
    remainder_2=${remainder#*,}
    [ "$remainder_2" != "$remainder" ] || usage
    add_mode=${remainder_2%%,*}
    add_session=${remainder_2#*,}
    [ "$add_session" != "$remainder_2" ] || usage
    case "$add_session" in *,*) usage ;; esac
    valid_id "$add_id" && valid_id "$add_provider" &&
      valid_session "$add_session" || usage
    case "$add_id" in none|owner|auto) usage ;; esac
    case "$add_mode" in persistent|turn) ;; *) usage ;; esac
    if list_contains "$agents" "$add_id"; then
      echo "participant already exists: $add_id" >&2
      exit 64
    fi
    case "$add_provider" in
      codex|claude) add_authority=decision ;;
      *) add_authority=advisory ;;
    esac
    new_agents=$agents,$add_id
    new_order=$order,$add_id
    ;;
  remove)
    remove_id=$value
    valid_id "$remove_id" || usage
    list_contains "$agents" "$remove_id" || usage
    if [ "$remove_id" = "$coordinator" ] || [ "$remove_id" = "$turn" ]; then
      echo "refusing to remove the coordinator or current turn holder" >&2
      exit 75
    fi
    new_agents=$(remove_from_list "$agents" "$remove_id")
    new_order=$(remove_from_list "$order" "$remove_id")
    [ -n "$new_agents" ] && [ -n "$new_order" ] || exit 65
    if [ "$manager" = "$remove_id" ]; then new_manager=none; fi
    if [ "$auto_launch" != none ] && list_contains "$auto_launch" "$remove_id"; then
      new_auto_launch=$(remove_from_list "$auto_launch" "$remove_id")
      if [ -z "$new_auto_launch" ]; then
        new_auto_launch=none
        new_auto_limit=0
      else
        auto_count=$(printf '%s\n' "$new_auto_launch" | awk -F, '{ print NF }')
        if [ "$new_auto_limit" -gt "$auto_count" ]; then new_auto_limit=$auto_count; fi
      fi
    fi
    ;;
  reorder)
    new_order=$value
    case "$new_order" in ''|,*|*,|*,,*) usage ;; esac
    old_ifs=$IFS
    IFS=,
    seen=
    reorder_count=0
    for reorder_id in $new_order; do
      valid_id "$reorder_id" || usage
      list_contains "$agents" "$reorder_id" || usage
      if list_contains "$seen" "$reorder_id"; then usage; fi
      if [ -z "$seen" ]; then seen=$reorder_id; else seen=$seen,$reorder_id; fi
      reorder_count=$((reorder_count + 1))
    done
    IFS=$old_ifs
    roster_count=$(printf '%s\n' "$agents" | awk -F, '{ print NF }')
    [ "$reorder_count" -eq "$roster_count" ] || usage
    ;;
esac

new_index=$(list_index "$new_order" "$agent_id")
[ -n "$new_index" ] || exit 65

if [ -n "$add_id" ]; then
  new_participant_dir=$state_dir/agents/$add_id
  if [ -e "$new_participant_dir" ]; then
    echo "participant directory already exists: $new_participant_dir" >&2
    exit 73
  fi
  mkdir -p "$new_participant_dir"
  participant_dir_created=1
  cat >"$new_participant_dir/PROMPT.md" <<EOF
# Cowork participant prompt: $add_id

Read repository instructions, then the local PROTOCOL.md, TASK.md, STATE.md, new
CHAT.md entries, and this prompt before acting. Use a process-unique session label.
Claim only a READY turn addressed to $add_id, work only after exact lease read-back,
append evidence with Author: $add_id, and hand off atomically. If selected as
Questioner, write the neutral owner question and enter OWNER_INPUT. Mode is
$add_mode; provider is $add_provider; authority is $add_authority.
EOF
  cat >"$new_participant_dir/NOTES.md" <<EOF
# Notes for $add_id

Optional scratch only. Shared decisions and evidence belong in CHAT.md; do not store
secrets here.
EOF
fi

timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
cp -p "$state_file" "$tmp_file"

awk -v agents="$new_agents" -v order="$new_order" -v manager="$new_manager" \
    -v auto_launch="$new_auto_launch" -v auto_limit="$new_auto_limit" \
    -v order_pos="$new_index" -v updated="$timestamp" -v entry="$owner_entry" \
    -v remove_id="$remove_id" -v add_id="$add_id" -v provider="${add_provider-}" \
    -v authority="${add_authority-}" -v mode="${add_mode-}" \
    -v session="${add_session-}" -v review="$review_round" '
  index($0, "Agents: ") == 1 { print "Agents: " agents; next }
  index($0, "Manager: ") == 1 { print "Manager: " manager; next }
  index($0, "Auto-launch: ") == 1 { print "Auto-launch: " auto_launch; next }
  index($0, "Auto-launch-limit: ") == 1 { print "Auto-launch-limit: " auto_limit; next }
  index($0, "Order: ") == 1 { print "Order: " order; next }
  index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
  index($0, "Updated: ") == 1 { print "Updated: " updated; next }
  index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
  remove_id != "" {
    if (index($0, "Provider-" remove_id ": ") == 1 ||
        index($0, "Authority-" remove_id ": ") == 1 ||
        index($0, "Mode-" remove_id ": ") == 1 ||
        index($0, "Session-" remove_id ": ") == 1 ||
        index($0, "Rating-" remove_id ": ") == 1) next
  }
  { print }
  END {
    if (add_id != "") {
      print "Provider-" add_id ": " provider
      print "Authority-" add_id ": " authority
      print "Mode-" add_id ": " mode
      print "Session-" add_id ": " session
      print "Rating-" add_id ": R" review "/pending/none"
    }
  }
' "$state_file" >"$tmp_file"

"$script_dir/validate-state.sh" "$tmp_file" >/dev/null
mv "$tmp_file" "$state_file"
tmp_file=
participant_dir_keep=1

[ "$(read_field Agents)" = "$new_agents" ] &&
  [ "$(read_field Order)" = "$new_order" ] &&
  [ "$(read_field Auto-launch)" = "$new_auto_launch" ] &&
  [ "$(read_field Last-entry)" = "$owner_entry" ] || {
    echo "RETRY reason=roster-readback-mismatch" >&2
    exit 75
  }

echo "ROSTER operation=$operation agents=$new_agents order=$new_order"
