#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: review-round.sh <open|rate|timeout|resolve|close> <agent-id> <session-label> <value> <chat-entry> [state-file]" >&2
  echo "value: deadline epoch for open; approve|notes|object|abstain for rate; auto for timeout; target agent for resolve; complete|abort for close" >&2
  exit 64
}

[ "$#" -ge 5 ] && [ "$#" -le 6 ] || usage

operation=$1
agent_id=$2
session_label=$3
value=$4
chat_entry=$5
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${6:-$script_dir/STATE.md}
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
rotate_list() {
  printf '%s\n' "$1" | awk -F, -v start="$2" '
    {
      out = ""
      for (offset = 0; offset < NF; offset++) {
        i = ((start + offset) % NF) + 1
        out = out (out == "" ? "" : ",") $i
      }
      print out
    }
  '
}

case "$operation" in open|rate|timeout|resolve|close) ;; *) usage ;; esac
case "$agent_id" in ''|*[!a-z0-9_-]*|[-_]*) usage ;; esac
case "$session_label" in ''|*[!A-Za-z0-9._:-]*) usage ;; esac
case "$chat_entry" in M*) ;; *) usage ;; esac
is_uint "${chat_entry#M}" || usage

case "$operation" in
  open) is_uint "$value" || usage ;;
  rate) case "$value" in approve|notes|object|abstain) ;; *) usage ;; esac ;;
  timeout) [ "$value" = auto ] || usage ;;
  resolve) case "$value" in ''|*[!a-z0-9_-]*|[-_]*) usage ;; esac ;;
  close) case "$value" in complete|abort) ;; *) usage ;; esac ;;
esac

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
coordinator=$(read_field Coordinator)
order=$(read_field Order)
review_round=$(read_field Review-round)
reviewers=$(read_field Reviewers)
review_deadline=$(read_field Review-deadline)
review_target=$(read_field Review-target)
review_minimum=$(read_field Review-minimum)
turn_timeout=$(read_field Turn-timeout-seconds)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
   [ -z "$lease" ] || [ -z "$round" ] || [ -z "$agents" ] ||
   [ -z "$coordinator" ] || [ -z "$order" ] || [ -z "$review_round" ] ||
   [ -z "$reviewers" ] || [ -z "$review_deadline" ] ||
   [ -z "$review_target" ] || [ -z "$review_minimum" ] ||
   [ -z "$turn_timeout" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
is_uint "$round" && is_uint "$review_round" && is_uint "$review_deadline" &&
  is_uint "$review_target" && is_uint "$review_minimum" &&
  is_uint "$turn_timeout" || exit 65
"$script_dir/validate-state.sh" "$state_file" >/dev/null
list_contains "$agents" "$agent_id" || usage

verify_live_lease() {
  if [ "$status" != WORKING ] || [ "$turn" != "$agent_id" ]; then
    echo "RETRY status=$status turn=$turn lease=$lease" >&2
    exit 75
  fi
  case "$lease" in
    "$agent_id/$session_label/claim/"*) ;;
    *) echo "RETRY reason=lease-mismatch lease=$lease" >&2; exit 75 ;;
  esac
}

timestamp=$(date '+%Y-%m-%d %H:%M:%S %z')
new_round=$round
report_review_round=$review_round

case "$operation" in
  open)
    verify_live_lease
    [ "$agent_id" = "$coordinator" ] || {
      echo "only the coordinator may open a review" >&2
      exit 75
    }
    [ "$reviewers" = none ] || {
      echo "RETRY reason=review-already-active reviewers=$reviewers" >&2
      exit 75
    }
    now_epoch=$(date '+%s')
    [ "$value" -gt "$now_epoch" ] || {
      echo "review deadline must be in the future" >&2
      exit 64
    }
    roster_count=$(printf '%s\n' "$order" | awk -F, '{ print NF }')
    [ "$roster_count" -gt 0 ] || exit 65
    next_review=$((review_round + 1))
    report_review_round=$next_review
    start_index=$(((next_review - 1) % roster_count))
    new_reviewers=$(rotate_list "$order" "$start_index")
    first_reviewer=${new_reviewers%%,*}
    first_session=$(read_field "Session-$first_reviewer")
    first_index=$(list_index "$order" "$first_reviewer")
    [ -n "$first_session" ] && [ -n "$first_index" ] || exit 65
    new_round=$((round + 1))

    tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
    cp -p "$state_file" "$tmp_file"
    awk -v status=READY -v turn="$first_reviewer" -v session="$first_session" \
        -v round="$new_round" -v updated="$timestamp" -v entry="$chat_entry" \
        -v order_pos="$first_index" -v review="$next_review" \
        -v reviewers="$new_reviewers" -v deadline="$value" '
      BEGIN {
        count = split(reviewers, ids, ",")
        for (i = 1; i <= count; i++) selected[ids[i]] = 1
      }
      index($0, "Status: ") == 1 { print "Status: " status; next }
      index($0, "Turn: ") == 1 { print "Turn: " turn; next }
      index($0, "Turn-session: ") == 1 { print "Turn-session: " session; next }
      index($0, "Round: ") == 1 { print "Round: " round; next }
      index($0, "Lease: ") == 1 { print "Lease: none"; next }
      index($0, "Updated: ") == 1 { print "Updated: " updated; next }
      index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
      index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
      index($0, "Turn-deadline: ") == 1 { print "Turn-deadline: " deadline; next }
      index($0, "Review-round: ") == 1 { print "Review-round: " review; next }
      index($0, "Reviewers: ") == 1 { print "Reviewers: " reviewers; next }
      index($0, "Review-deadline: ") == 1 { print "Review-deadline: " deadline; next }
      index($0, "Rating-") == 1 {
        split($0, pair, ": ")
        id = substr(pair[1], 8)
        if (selected[id]) { print "Rating-" id ": R" review "/pending/none"; next }
      }
      { print }
    ' "$state_file" >"$tmp_file"
    expected_status=READY
    expected_turn=$first_reviewer
    expected_rating=R$next_review/pending/none
    expected_rating_agent=$first_reviewer
    ;;

  rate)
    verify_live_lease
    [ "$reviewers" != none ] && list_contains "$reviewers" "$agent_id" || {
      echo "agent is not in the active review: $agent_id" >&2
      exit 75
    }
    current_rating=$(read_field "Rating-$agent_id")
    [ "$current_rating" = "R$review_round/pending/none" ] || {
      echo "RETRY reason=rating-already-recorded rating=$current_rating" >&2
      exit 75
    }

    next_reviewer=
    found_current=0
    old_ifs=$IFS
    IFS=,
    for reviewer in $reviewers; do
      if [ "$found_current" -eq 1 ]; then
        reviewer_rating=$(read_field "Rating-$reviewer")
        if [ "$reviewer_rating" = "R$review_round/pending/none" ]; then
          next_reviewer=$reviewer
          break
        fi
      fi
      if [ "$reviewer" = "$agent_id" ]; then found_current=1; fi
    done
    IFS=$old_ifs
    [ "$found_current" -eq 1 ] || exit 65
    [ -n "$next_reviewer" ] || next_reviewer=$coordinator
    next_session=$(read_field "Session-$next_reviewer")
    next_index=$(list_index "$order" "$next_reviewer")
    [ -n "$next_session" ] && [ -n "$next_index" ] || exit 65
    now_epoch=$(date '+%s')
    if [ "$turn_timeout" -eq 0 ]; then next_deadline=0; else next_deadline=$((now_epoch + turn_timeout)); fi
    new_round=$((round + 1))

    tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
    cp -p "$state_file" "$tmp_file"
    awk -v turn="$next_reviewer" -v session="$next_session" -v round="$new_round" \
        -v updated="$timestamp" -v entry="$chat_entry" -v order_pos="$next_index" \
        -v deadline="$next_deadline" -v agent="$agent_id" \
        -v rating="R$review_round/$value/$chat_entry" '
      index($0, "Status: ") == 1 { print "Status: READY"; next }
      index($0, "Turn: ") == 1 { print "Turn: " turn; next }
      index($0, "Turn-session: ") == 1 { print "Turn-session: " session; next }
      index($0, "Round: ") == 1 { print "Round: " round; next }
      index($0, "Lease: ") == 1 { print "Lease: none"; next }
      index($0, "Updated: ") == 1 { print "Updated: " updated; next }
      index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
      index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
      index($0, "Turn-deadline: ") == 1 { print "Turn-deadline: " deadline; next }
      index($0, "Rating-" agent ": ") == 1 { print "Rating-" agent ": " rating; next }
      { print }
    ' "$state_file" >"$tmp_file"
    expected_status=READY
    expected_turn=$next_reviewer
    expected_rating=R$review_round/$value/$chat_entry
    expected_rating_agent=$agent_id
    ;;

  timeout)
    [ "$agent_id" = "$coordinator" ] || usage
    coordinator_session=$(read_field "Session-$coordinator")
    if [ "$status" != READY ] || [ "$lease" != none ] ||
       [ "$reviewers" = none ] || [ -z "$coordinator_session" ]; then
      echo "RETRY reason=review-timeout-boundary status=$status lease=$lease" >&2
      exit 75
    fi
    if [ "$coordinator_session" != any ] && [ "$coordinator_session" != "$session_label" ]; then
      echo "OTHER_SESSION agent=$agent_id expected=$coordinator_session" >&2
      exit 76
    fi
    now_epoch=$(date '+%s')
    if [ "$review_deadline" -eq 0 ] || [ "$now_epoch" -lt "$review_deadline" ]; then
      echo "RETRY reason=review-deadline-not-reached deadline=$review_deadline" >&2
      exit 75
    fi
    coordinator_index=$(list_index "$order" "$coordinator")
    [ -n "$coordinator_index" ] || exit 65
    new_round=$((round + 1))

    tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
    cp -p "$state_file" "$tmp_file"
    awk -v coordinator="$coordinator" -v session="$coordinator_session" \
        -v round="$new_round" -v updated="$timestamp" -v entry="$chat_entry" \
        -v order_pos="$coordinator_index" -v review="$review_round" \
        -v reviewers="$reviewers" '
      BEGIN {
        count = split(reviewers, ids, ",")
        for (i = 1; i <= count; i++) selected[ids[i]] = 1
      }
      index($0, "Status: ") == 1 { print "Status: READY"; next }
      index($0, "Turn: ") == 1 { print "Turn: " coordinator; next }
      index($0, "Turn-session: ") == 1 { print "Turn-session: " session; next }
      index($0, "Round: ") == 1 { print "Round: " round; next }
      index($0, "Lease: ") == 1 { print "Lease: none"; next }
      index($0, "Updated: ") == 1 { print "Updated: " updated; next }
      index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
      index($0, "Order-index: ") == 1 { print "Order-index: " order_pos; next }
      index($0, "Turn-deadline: ") == 1 { print "Turn-deadline: 0"; next }
      index($0, "Rating-") == 1 {
        split($0, pair, ": ")
        id = substr(pair[1], 8)
        if (selected[id] && pair[2] == "R" review "/pending/none") {
          print "Rating-" id ": R" review "/no-response/" entry
          next
        }
      }
      { print }
    ' "$state_file" >"$tmp_file"
    expected_status=READY
    expected_turn=$coordinator
    expected_rating=
    expected_rating_agent=
    ;;

  resolve)
    verify_live_lease
    actor_provider=$(read_field "Provider-$agent_id")
    actor_authority=$(read_field "Authority-$agent_id")
    case "$actor_provider/$actor_authority" in codex/decision|claude/decision) ;; *) usage ;; esac
    target_id=$value
    list_contains "$reviewers" "$target_id" || usage
    target_authority=$(read_field "Authority-$target_id")
    [ "$target_authority" = advisory ] || {
      echo "a decision-participant object requires another decision participant or the owner" >&2
      exit 75
    }
    target_rating=$(read_field "Rating-$target_id")
    [ "$target_rating" != "${target_rating#R$review_round/object/}" ] || {
      echo "target has no active object: $target_id" >&2
      exit 75
    }

    tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
    cp -p "$state_file" "$tmp_file"
    awk -v updated="$timestamp" -v entry="$chat_entry" -v target="$target_id" \
        -v rating="R$review_round/resolved-object/$chat_entry" '
      index($0, "Updated: ") == 1 { print "Updated: " updated; next }
      index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
      index($0, "Rating-" target ": ") == 1 { print "Rating-" target ": " rating; next }
      { print }
    ' "$state_file" >"$tmp_file"
    expected_status=WORKING
    expected_turn=$agent_id
    expected_rating=R$review_round/resolved-object/$chat_entry
    expected_rating_agent=$target_id
    ;;

  close)
    verify_live_lease
    [ "$agent_id" = "$coordinator" ] || {
      echo "only the coordinator may close a review" >&2
      exit 75
    }
    [ "$reviewers" != none ] || {
      echo "RETRY reason=no-active-review" >&2
      exit 75
    }
    if [ "$value" = complete ]; then
      "$script_dir/review-summary.sh" "$state_file" "$state_dir/CHAT.md" "$review_round"
    fi

    tmp_file=$(mktemp "$state_dir/.STATE.tmp.XXXXXX") || exit 73
    cp -p "$state_file" "$tmp_file"
    awk -v updated="$timestamp" -v entry="$chat_entry" '
      index($0, "Updated: ") == 1 { print "Updated: " updated; next }
      index($0, "Last-entry: ") == 1 { print "Last-entry: " entry; next }
      index($0, "Reviewers: ") == 1 { print "Reviewers: none"; next }
      index($0, "Review-deadline: ") == 1 { print "Review-deadline: 0"; next }
      { print }
    ' "$state_file" >"$tmp_file"
    expected_status=WORKING
    expected_turn=$agent_id
    expected_rating=
    expected_rating_agent=
    ;;
esac

"$script_dir/validate-state.sh" "$tmp_file" >/dev/null
mv "$tmp_file" "$state_file"
tmp_file=

if [ "$(read_field Status)" != "$expected_status" ] ||
   [ "$(read_field Turn)" != "$expected_turn" ] ||
   [ "$(read_field Last-entry)" != "$chat_entry" ]; then
  echo "RETRY reason=review-readback-mismatch" >&2
  exit 75
fi
if [ -n "$expected_rating_agent" ] &&
   [ "$(read_field "Rating-$expected_rating_agent")" != "$expected_rating" ]; then
  echo "RETRY reason=rating-readback-mismatch" >&2
  exit 75
fi

echo "REVIEW operation=$operation status=$expected_status turn=$expected_turn round=$report_review_round"
