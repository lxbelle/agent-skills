#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: validate-state.sh [state-file]" >&2
  exit 64
}

[ "$#" -le 1 ] || usage

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${1:-$script_dir/STATE.md}

if [ ! -f "$state_file" ] || [ -L "$state_file" ]; then
  echo "state file is missing or unsafe: $state_file" >&2
  exit 66
fi

fail() {
  echo "state is malformed: $state_file ($1)" >&2
  exit 65
}

is_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

valid_id() {
  case "$1" in ''|*[!a-z0-9_-]*|[-_]*) return 1 ;; *) return 0 ;; esac
}

valid_session() {
  case "$1" in ''|*[!A-Za-z0-9._:-]*) return 1 ;; *) return 0 ;; esac
}

list_contains() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}

field_count() {
  awk -v key="$1" 'index($0, key ": ") == 1 { count++ }
    END { print count + 0 }' "$state_file"
}

read_field() {
  count=$(field_count "$1")
  [ "$count" -eq 1 ] || fail "field $1 occurs $count times"
  awk -v key="$1" 'index($0, key ": ") == 1 {
    print substr($0, length(key) + 3)
    exit
  }' "$state_file"
}

validate_list() {
  list=$1
  case "$list" in ''|,*|*,|*,,*) return 1 ;; esac
  old_ifs=$IFS
  IFS=,
  seen=
  for item in $list; do
    valid_id "$item" || { IFS=$old_ifs; return 1; }
    list_contains "$seen" "$item" && { IFS=$old_ifs; return 1; }
    if [ -z "$seen" ]; then seen=$item; else seen=$seen,$item; fi
  done
  IFS=$old_ifs
}

valid_entry_or_none() {
  case "$1" in
    none) return 0 ;;
    M*) is_uint "${1#M}" ;;
    *) return 1 ;;
  esac
}

protocol_version=$(read_field Protocol-version)
[ "$protocol_version" = 2 ] || {
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
}

workstream=$(read_field Workstream)
status=$(read_field Status)
turn=$(read_field Turn)
turn_session=$(read_field Turn-session)
round=$(read_field Round)
lease=$(read_field Lease)
updated=$(read_field Updated)
last_entry=$(read_field Last-entry)
agents=$(read_field Agents)
coordinator=$(read_field Coordinator)
manager=$(read_field Manager)
order_policy=$(read_field Order-policy)
order=$(read_field Order)
order_index=$(read_field Order-index)
turn_timeout=$(read_field Turn-timeout-seconds)
turn_deadline=$(read_field Turn-deadline)
review_round=$(read_field Review-round)
reviewers=$(read_field Reviewers)
review_deadline=$(read_field Review-deadline)
review_target=$(read_field Review-target)
review_minimum=$(read_field Review-minimum)
questioner=$(read_field Questioner)
dispute_entry=$(read_field Dispute-entry)
launch_mode=$(read_field Launch-mode)
auto_launch=$(read_field Auto-launch)
auto_limit=$(read_field Auto-launch-limit)
resume_after_owner=$(read_field Resume-after-owner)
question_entry=$(read_field Question-entry)
poll_seconds=$(read_field Poll-seconds)
max_wait=$(read_field Max-wait-seconds)

valid_id "$workstream" || fail Workstream
validate_list "$agents" || fail Agents
valid_id "$coordinator" && list_contains "$agents" "$coordinator" || fail Coordinator
case "$manager" in
  none) ;;
  *) valid_id "$manager" && list_contains "$agents" "$manager" || fail Manager ;;
esac

case "$status" in SETUP|READY|WORKING|OWNER_INPUT|FINAL) ;; *) fail Status ;; esac
valid_session "$turn_session" || fail Turn-session
is_uint "$round" && is_uint "$order_index" && is_uint "$turn_timeout" &&
  is_uint "$turn_deadline" && is_uint "$review_round" &&
  is_uint "$review_deadline" && is_uint "$review_target" &&
  is_uint "$review_minimum" && is_uint "$auto_limit" &&
  is_uint "$poll_seconds" && is_uint "$max_wait" || fail numeric-fields
[ "$review_target" -gt 0 ] && [ "$review_minimum" -gt 0 ] &&
  [ "$review_minimum" -le "$review_target" ] || fail review-thresholds
[ "$poll_seconds" -gt 0 ] || fail Poll-seconds
[ -n "$updated" ] || fail Updated
valid_entry_or_none "$last_entry" || fail Last-entry

validate_list "$order" || fail Order
agent_count=$(printf '%s\n' "$agents" | awk -F, '{ print NF }')
order_count=$(printf '%s\n' "$order" | awk -F, '{ print NF }')
[ "$agent_count" -eq "$order_count" ] || fail Order
old_ifs=$IFS
IFS=,
for participant in $agents; do
  list_contains "$order" "$participant" || { IFS=$old_ifs; fail Order; }

  provider=$(read_field "Provider-$participant")
  authority=$(read_field "Authority-$participant")
  mode=$(read_field "Mode-$participant")
  session=$(read_field "Session-$participant")
  rating=$(read_field "Rating-$participant")
  valid_id "$provider" || { IFS=$old_ifs; fail "Provider-$participant"; }
  case "$provider/$authority" in
    codex/decision|claude/decision) ;;
    codex/*|claude/*) IFS=$old_ifs; fail "Authority-$participant" ;;
    */advisory) ;;
    *) IFS=$old_ifs; fail "Authority-$participant" ;;
  esac
  case "$mode" in persistent|turn) ;; *) IFS=$old_ifs; fail "Mode-$participant" ;; esac
  valid_session "$session" || { IFS=$old_ifs; fail "Session-$participant"; }

  rating_round=${rating%%/*}
  rating_rest=${rating#*/}
  [ "$rating_rest" != "$rating" ] || { IFS=$old_ifs; fail "Rating-$participant"; }
  rating_value=${rating_rest%%/*}
  rating_entry=${rating_rest#*/}
  [ "$rating_entry" != "$rating_rest" ] || { IFS=$old_ifs; fail "Rating-$participant"; }
  case "$rating_entry" in */*) IFS=$old_ifs; fail "Rating-$participant" ;; esac
  case "$rating_round" in R*) is_uint "${rating_round#R}" || { IFS=$old_ifs; fail "Rating-$participant"; } ;; *) IFS=$old_ifs; fail "Rating-$participant" ;; esac
  case "$rating_value/$rating_entry" in
    pending/none) ;;
    approve/M*|notes/M*|object/M*|abstain/M*|no-response/M*|resolved-object/M*)
      is_uint "${rating_entry#M}" || { IFS=$old_ifs; fail "Rating-$participant"; }
      ;;
    *) IFS=$old_ifs; fail "Rating-$participant" ;;
  esac
done
IFS=$old_ifs

if ! awk -F: -v agents=",$agents," '
  /^(Provider|Authority|Mode|Session|Rating)-/ {
    id = $1
    sub(/^(Provider|Authority|Mode|Session|Rating)-/, "", id)
    if (index(agents, "," id ",") == 0) exit 1
  }
' "$state_file"; then
  fail removed-participant-fields
fi

case "$order_policy" in queue|round-robin) ;; *) fail Order-policy ;; esac
[ "$order_index" -lt "$order_count" ] || fail Order-index
if [ "$status" = SETUP ] || [ "$status" = READY ] || [ "$status" = WORKING ]; then
  list_contains "$agents" "$turn" || fail Turn
  indexed_turn=$(printf '%s\n' "$order" | awk -F, -v field=$((order_index + 1)) '{ print $field }')
  [ "$indexed_turn" = "$turn" ] || fail Order-index
else
  [ "$turn" = owner ] || fail Turn
fi

case "$status" in
  WORKING)
    case "$lease" in "$turn/"*"/claim/"*) ;; *) fail Lease ;; esac
    lease_rest=${lease#"$turn/"}
    lease_session=${lease_rest%%/*}
    valid_session "$lease_session" || fail Lease
    configured_session=$(read_field "Session-$turn")
    if [ "$configured_session" != any ] && [ "$configured_session" != "$lease_session" ]; then
      fail Lease
    fi
    ;;
  *) [ "$lease" = none ] || fail Lease ;;
esac

if [ "$reviewers" = none ]; then
  [ "$review_deadline" -eq 0 ] || fail Review-deadline
else
  validate_list "$reviewers" || fail Reviewers
  [ "$review_deadline" -gt 0 ] || fail Review-deadline
  old_ifs=$IFS
  IFS=,
  for reviewer in $reviewers; do
    list_contains "$agents" "$reviewer" || { IFS=$old_ifs; fail Reviewers; }
    reviewer_rating=$(read_field "Rating-$reviewer")
    case "$reviewer_rating" in R"$review_round"/*) ;; *) IFS=$old_ifs; fail "Rating-$reviewer" ;; esac
  done
  IFS=$old_ifs
fi

case "$questioner" in
  none) ;;
  *) valid_id "$questioner" && list_contains "$agents" "$questioner" || fail Questioner ;;
esac
valid_entry_or_none "$dispute_entry" || fail Dispute-entry
valid_entry_or_none "$question_entry" || fail Question-entry
case "$resume_after_owner" in
  none) ;;
  *) valid_id "$resume_after_owner" && list_contains "$agents" "$resume_after_owner" || fail Resume-after-owner ;;
esac
if [ "$status" = OWNER_INPUT ]; then
  [ "$questioner" != none ] && [ "$question_entry" != none ] &&
    [ "$resume_after_owner" != none ] || fail OWNER_INPUT
fi

case "$launch_mode" in manual|automatic|unset) ;; *) fail Launch-mode ;; esac
if [ "$auto_launch" = none ]; then
  [ "$auto_limit" -eq 0 ] || fail Auto-launch-limit
  if [ "$launch_mode" = automatic ] && [ "$status" != SETUP ]; then fail Auto-launch; fi
else
  validate_list "$auto_launch" || fail Auto-launch
  auto_count=$(printf '%s\n' "$auto_launch" | awk -F, '{ print NF }')
  old_ifs=$IFS
  IFS=,
  for auto_agent in $auto_launch; do
    list_contains "$agents" "$auto_agent" || { IFS=$old_ifs; fail Auto-launch; }
  done
  IFS=$old_ifs
  [ "$launch_mode" = automatic ] && [ "$auto_limit" -gt 0 ] &&
    [ "$auto_limit" -le "$auto_count" ] || fail Auto-launch-limit
fi
if [ "$launch_mode" != automatic ]; then
  [ "$auto_launch" = none ] && [ "$auto_limit" -eq 0 ] || fail Auto-launch
fi

echo "VALID protocol=2 agents=$agent_count status=$status"
