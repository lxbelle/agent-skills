#!/bin/sh
set -eu
set -f

usage() {
  echo "usage: review-summary.sh [state-file] [chat-file] [review-round]" >&2
  exit 64
}

[ "$#" -le 3 ] || usage

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${1:-$script_dir/STATE.md}
chat_file=${2:-$script_dir/CHAT.md}

is_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}
list_contains() {
  case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac
}

if [ ! -f "$state_file" ] || [ -L "$state_file" ]; then
  echo "state file is missing or unsafe: $state_file" >&2
  exit 66
fi
if [ ! -f "$chat_file" ] || [ -L "$chat_file" ]; then
  echo "chat file is missing or unsafe: $chat_file" >&2
  exit 66
fi

state_snapshot=$(mktemp "${TMPDIR:-/tmp}/cowork-state.XXXXXX") || exit 73
chat_snapshot=$(mktemp "${TMPDIR:-/tmp}/cowork-chat.XXXXXX") || {
  rm -f "$state_snapshot"
  exit 73
}
cleanup() {
  rm -f "$state_snapshot" "$chat_snapshot"
}
trap cleanup 0
trap 'exit 130' HUP INT TERM
cp "$state_file" "$state_snapshot" || exit 66
cp "$chat_file" "$chat_snapshot" || exit 66

read_field() {
  awk -v key="$1" 'index($0, key ": ") == 1 {
    print substr($0, length(key) + 3)
    exit
  }' "$state_snapshot"
}

protocol_version=$(read_field Protocol-version)
agents=$(read_field Agents)
reviewers=$(read_field Reviewers)
state_round=$(read_field Review-round)
review_target=$(read_field Review-target)
review_minimum=$(read_field Review-minimum)

if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
  echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
  exit 78
fi
if [ -z "$protocol_version" ] || [ -z "$agents" ] || [ -z "$reviewers" ] ||
   [ -z "$state_round" ] || [ -z "$review_target" ] ||
   [ -z "$review_minimum" ]; then
  echo "state is malformed: $state_file" >&2
  exit 65
fi
is_uint "$state_round" && is_uint "$review_target" &&
  is_uint "$review_minimum" || exit 65
"$script_dir/validate-state.sh" "$state_snapshot" >/dev/null

review_round=${3:-$state_round}
is_uint "$review_round" || usage
[ "$reviewers" != none ] || {
  echo "WAIT reason=no-active-review"
  exit 75
}

entry_matches() {
  entry=$1
  value=$2
  awk -v heading="## $entry " -v round="$review_round" -v rating="$value" '
    index($0, "## ") == 1 {
      if (inside) exit
      inside = index($0, heading) == 1
      next
    }
    inside && $0 == "- Review-round: " round { saw_round = 1 }
    inside && $0 == "- Rating: " rating { saw_rating = 1 }
    END { exit !(saw_round && saw_rating) }
  ' "$chat_snapshot"
}

approvals=0
objects=0
incomplete=0
decision_approvals=0
reviewer_count=0

old_ifs=$IFS
IFS=,
for participant in $agents; do
  case "$participant" in ''|*[!a-z0-9_-]*|[-_]*) exit 65 ;; esac
  responses=$(awk -v author="$participant" '
    $0 == "- Author: " author { count++ }
    END { print count + 0 }
  ' "$chat_snapshot")
  provider=$(read_field "Provider-$participant")
  authority=$(read_field "Authority-$participant")
  rating=$(read_field "Rating-$participant")
  [ -n "$provider" ] && [ -n "$authority" ] && [ -n "$rating" ] || exit 65

  if list_contains "$reviewers" "$participant"; then
    reviewer=yes
    reviewer_count=$((reviewer_count + 1))
    rating_round=${rating%%/*}
    rating_rest=${rating#*/}
    [ "$rating_rest" != "$rating" ] || exit 65
    rating_value=${rating_rest%%/*}
    rating_entry=${rating_rest#*/}
    [ "$rating_entry" != "$rating_rest" ] || exit 65
    case "$rating_entry" in */*) exit 65 ;; esac
    case "$rating_round" in R*) ;; *) exit 65 ;; esac
    is_uint "${rating_round#R}" || exit 65

    if [ "${rating_round#R}" -ne "$review_round" ]; then
      rating_value=pending
      rating_entry=none
    fi

    case "$rating_value" in
      pending)
        incomplete=$((incomplete + 1))
        ;;
      approve|notes)
        approvals=$((approvals + 1))
        if [ "$authority" = decision ]; then
          decision_approvals=$((decision_approvals + 1))
        fi
        ;;
      object)
        objects=$((objects + 1))
        ;;
      abstain|no-response|resolved-object)
        ;;
      *) exit 65 ;;
    esac

    if [ "$rating_value" != pending ]; then
      case "$rating_entry" in M*) ;; *) exit 65 ;; esac
      is_uint "${rating_entry#M}" || exit 65
      entry_matches "$rating_entry" "$rating_value" || {
        echo "invalid rating evidence: agent=$participant entry=$rating_entry" >&2
        exit 65
      }
    fi
  else
    reviewer=no
  fi

  printf 'PARTICIPANT agent=%s provider=%s authority=%s responses=%s reviewer=%s rating=%s\n' \
    "$participant" "$provider" "$authority" "$responses" "$reviewer" "$rating"
done
IFS=$old_ifs

[ "$reviewer_count" -gt 0 ] || exit 65
printf 'COVERAGE round=%s reviewers=%s approvals=%s target=%s minimum=%s decision-approvals=%s incomplete=%s objects=%s\n' \
  "$review_round" "$reviewer_count" "$approvals" "$review_target" \
  "$review_minimum" "$decision_approvals" "$incomplete" "$objects"

if [ "$objects" -gt 0 ]; then
  echo "OBJECT result=blocked"
  exit 77
fi
if [ "$incomplete" -gt 0 ]; then
  echo "WAIT result=incomplete"
  exit 75
fi
if [ "$approvals" -lt "$review_minimum" ]; then
  echo "OWNER_INPUT reason=review-minimum"
  exit 75
fi
if [ "$decision_approvals" -lt 1 ]; then
  echo "OWNER_INPUT reason=no-codex-or-claude-approval"
  exit 75
fi
if [ "$approvals" -ge "$review_target" ]; then
  target_met=yes
else
  target_met=no
fi
echo "ACCEPT target-met=$target_met"
