#!/bin/sh
set -eu

usage() {
  echo "usage: watch-turn.sh <agent-id> <session-label> [state-file]" >&2
  echo "agent-id: lowercase letters, digits, underscores, hyphens; starts alphanumeric" >&2
  echo "session-label: letters, digits, dots, underscores, colons, hyphens" >&2
  exit 64
}

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage

agent_id=$1
session_label=$2
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
state_file=${3:-$script_dir/STATE.md}

case "$agent_id" in
  ''|*[!a-z0-9_-]*|[-_]*) usage ;;
esac
case "$session_label" in
  ''|*[!A-Za-z0-9._:-]*) usage ;;
esac

is_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

poll_override=${COWORK_POLL_SECONDS-}
max_wait_override=${COWORK_MAX_WAIT_SECONDS-}
max_bad_reads=${COWORK_MAX_BAD_READS:-3}

if [ -n "$poll_override" ]; then
  is_uint "$poll_override" || usage
  [ "$poll_override" -gt 0 ] || usage
fi
if [ -n "$max_wait_override" ]; then
  is_uint "$max_wait_override" || usage
fi
is_uint "$max_bad_reads" || usage
[ "$max_bad_reads" -gt 0 ] || usage

snapshot=$(mktemp "${TMPDIR:-/tmp}/cowork-watch.XXXXXX") || exit 73
cleanup() {
  rm -f "$snapshot"
}
trap cleanup 0
trap 'exit 130' HUP INT TERM

read_field() {
  awk -v key="$1" 'index($0, key ": ") == 1 {
    print substr($0, length(key) + 3)
    exit
  }' "$snapshot"
}

poll_seconds=${poll_override:-60}
max_wait_seconds=${max_wait_override:-3600}
elapsed=0
bad_reads=0
bad_kind=missing

while :; do
  valid=1
  if cp "$state_file" "$snapshot" 2>/dev/null; then
    protocol_version=$(read_field Protocol-version)
    status=$(read_field Status)
    turn=$(read_field Turn)
    turn_session=$(read_field Turn-session)
    updated=$(read_field Updated)
    agents=$(read_field Agents)
    lease=$(read_field Lease)
    state_poll=$(read_field Poll-seconds)
    state_max_wait=$(read_field Max-wait-seconds)

    if [ -n "$protocol_version" ] && [ "$protocol_version" != 2 ]; then
      echo "UNSUPPORTED protocol=$protocol_version state=$state_file" >&2
      exit 78
    fi

    if [ -z "$protocol_version" ] || [ -z "$status" ] || [ -z "$turn" ] ||
       [ -z "$turn_session" ] || [ -z "$agents" ] || [ -z "$state_poll" ] ||
       [ -z "$state_max_wait" ]; then
      valid=0
      bad_kind=malformed
    elif ! is_uint "$state_poll" || [ "$state_poll" -eq 0 ] ||
         ! is_uint "$state_max_wait"; then
      valid=0
      bad_kind=malformed
    elif ! "$script_dir/validate-state.sh" "$snapshot" >/dev/null 2>&1; then
      valid=0
      bad_kind=malformed
    fi
  else
    valid=0
    bad_kind=missing
  fi

  if [ "$valid" -eq 1 ]; then
    bad_reads=0
    poll_seconds=${poll_override:-$state_poll}
    max_wait_seconds=${max_wait_override:-$state_max_wait}

    case ",$agents," in
      *",$agent_id,"*) ;;
      *)
        echo "agent is not registered in Agents: $agent_id" >&2
        exit 64
        ;;
    esac

    case "$status" in
      READY)
        if [ "$turn" = "$agent_id" ]; then
          if [ "$turn_session" = any ] || [ "$turn_session" = "$session_label" ]; then
            echo "ACT agent=$agent_id session=$session_label updated=$updated"
            exit 0
          fi
          echo "OTHER_SESSION agent=$agent_id expected=$turn_session" >&2
          exit 76
        fi
        ;;
      SETUP|WORKING)
        ;;
      OWNER_INPUT|FINAL)
        echo "STOP status=$status turn=$turn updated=$updated"
        exit 0
        ;;
      *)
        valid=0
        bad_kind=malformed
        ;;
    esac
  fi

  if [ "$valid" -eq 0 ]; then
    bad_reads=$((bad_reads + 1))
    if [ "$bad_reads" -ge "$max_bad_reads" ]; then
      if [ "$bad_kind" = missing ]; then
        echo "state file remained unreadable: $state_file" >&2
        exit 66
      fi
      echo "state remained malformed after $bad_reads reads: $state_file" >&2
      exit 65
    fi
  fi

  if [ "$max_wait_seconds" -gt 0 ] && [ "$elapsed" -ge "$max_wait_seconds" ]; then
    echo "CHECK agent=$agent_id status=${status:-unknown} turn=${turn:-unknown} lease=${lease:-unknown}"
    exit 75
  fi

  sleep "$poll_seconds"
  elapsed=$((elapsed + poll_seconds))
done
