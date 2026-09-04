---
name: cowork
description: Coordinate any-size model roster on one repository task with safe sequential turns, durable handoffs, explicit launch authority, response counts, evidence-backed ratings, and owner/final stops. Use for ongoing multi-agent collaboration, not parallel subtask delegation.
license: MIT
metadata:
  version: "0.2.0"
---

# Cowork

Coordinate an arbitrary-size roster through one sequential writer and verified lease.
Persist the task, roster, turn, evidence, ratings, and handoffs in project-local files
so participants can resume after compaction or process restart. Cowork coordinates an
already authorized task; it does not initialize Startup, grant permissions, or turn
the roster into a parallel swarm.

## Establish the roster

Read applicable repository instructions and inspect the worktree. Establish:

- one bounded objective, scope, exclusions, and acceptance evidence;
- stable participant identifiers, model providers, participant modes, and explicit
  turn order, with one coordinator and optional manager;
- `manual` or `automatic` launch mode selected by the owner;
- for automatic mode, the exact allowlisted participant identifiers and maximum
  launch count—never infer that an unbounded roster authorizes unbounded launches;
- the repository's private or ignored agent-state location.

Use `.agents/cowork/` by default. Resume an existing active workspace rather than
overwriting it. Preserve a final workspace before starting another. Do not change
ignore rules or expose local coordination merely to fit the default path.

On POSIX shell, initialize with one or more participant specifications:

```sh
path/to/cowork/scripts/init-cowork.sh \
  /absolute/repository/root coordinator-id manager-id-or-none workstream-id manual \
  'codex,codex,persistent,any' \
  'claude,claude,persistent,any' \
  'deepseek,deepseek,turn,any'
```

Each specification is `agent-id,provider,mode,session`, where mode is `persistent` or
`turn`; providers are lowercase identifiers such as `codex`, `claude`, `deepseek`,
`grok`, or `qwen`. Codex and Claude receive decision authority; other providers are
advisory. The initializer refuses an existing workspace and creates one prompt and
notes file per participant. Without POSIX shell, reproduce the layout and invariants
from [Cowork protocol](references/protocol.md) with native atomic filesystem tools.

While state is `SETUP`, the coordinator completes `TASK.md`, including launch
allowlist, explicit queue/order, deadlines, acceptance thresholds, participant modes,
and evidence requirements. Record setup in `CHAT.md`, atomically change state to
`READY`, then claim. Do not launch participants against an unfinished task contract.

## Launch only the authorized participants

If launch mode is absent or `unset`, launch nobody and ask the owner. In `manual`
mode, prepare prompts and exact paths; the owner launches participants. In
`automatic` mode, start only identifiers listed in `Auto-launch`, never more than
`Auto-launch-limit`, through an already configured interface. Adding a roster member
does not launch it.

Read [Launching and supervision](references/launching.md) before starting, resuming,
or stopping participants. Never install a launcher, alter authentication or billing,
weaken sandboxing, use permission-bypass flags, or claim a session is live without an
observed identifier.

## Run sequential turns

Each participant follows this loop:

1. Read repository instructions, local `PROTOCOL.md`, `TASK.md`, `STATE.md`, new
   `CHAT.md` entries, and its prompt. Refuse an unsupported protocol version.
2. When `Status: READY`, `Turn`, and `Turn-session` address it, claim with
   `.agents/cowork/claim-turn.sh <agent-id> <session-label>`. Work only after exact
   lease read-back. A duplicate process with the same agent identifier is still a
   competing writer.
3. Complete one bounded queue operation. Only the verified lease holder edits task,
   Cowork, or public repository files. Append a structured chat entry with explicit
   `Author`, outcome, evidence, concerns, and exact next operation.
4. Hand off with `advance-turn.sh handoff`, naming the next participant for `queue`
   policy or `auto` for `round-robin`. The helper validates the lease and atomically
   advances `Turn`, session, order index, round, and deadline.
5. A `persistent` participant runs the low-frequency watcher after handoff. A `turn`
   participant exits and reconstructs context when invoked for its next task or
   rating. Never invoke participants merely to observe.

Deadlines may skip an unclaimed `READY` turn under the coordinator's lock. They never
expire `WORKING`; recovery still needs evidence that the exact lease process ended or
owner direction. Membership changes require owner authorization, the coordinator's
verified lease, and no active review round. Read the detailed mutation and recovery
rules in [Cowork protocol](references/protocol.md).

## Count responses and collect ratings

Response counts are derived from participant-authored chat entries and never affect
authority or vote weight. Open an explicit review round by snapshotting and rotating
the roster order, setting its deadline, and resetting `Rating-<id>` for the snapshot.
Every reviewer is asked for one evidence-bearing value:

- `approve`: reviewed and would ship unchanged;
- `notes`: would ship with only non-blocking observations;
- `object`: one concrete blocking finding with evidence;
- `abstain`: explicitly did not review or lacks relevant competence.

After the deadline, the coordinator records missing ratings as `no-response`; never
forge `abstain`. An evidence-backed decision by a Codex or Claude participant settles
an advisory disagreement. At least one such decision-authority participant must rate
`approve` or `notes` for final acceptance. New concrete evidence, governing safety
rules, or the owner may reopen a decision.

Every chat entry referenced by `Rating-<id>` names the same review round and exact
rating value. In particular, timeout evidence uses `Rating: no-response` and an
advisory-object resolution uses `Rating: resolved-object`; these are system
dispositions, not votes forged on behalf of another participant.

Use `review-round.sh` for open, rate, timeout, advisory-object resolution, and
verified close or abort so the snapshot, routing, and aggregate rating change
atomically.

Run `review-summary.sh` to print per-participant response counts, ratings, blockers,
coverage target, and acceptance result. It is read-only. The coordinator uses the
review helper to close an accepted or aborted snapshot while retaining its lease,
then applies the next explicit state transition. The target and minimum rules,
resolved-object handling, rotated review order, and validation limits are defined in
[Cowork protocol](references/protocol.md).

## Route disputes and stop deliberately

When a disagreement has no concrete next change, use `select-questioner.sh` once.
It chooses the configured manager; otherwise it randomly selects an active Codex or
Claude participant; if neither exists, it randomly selects any active participant.
All others wait. The selected questioner records one neutral owner question with the
competing positions and evidence, then sets `OWNER_INPUT` and stops too. Randomness
selects communication duty, not authority.

Final requires the declared acceptance rule and recorded evidence scope. `FINAL`
does not imply unrun tests, deployment, publication, commit, or owner acceptance.
For duplicate processes, interrupted leases, roster mutations, missed turns, review
deadlines, owner answers, or archival, follow [Cowork protocol](references/protocol.md).
