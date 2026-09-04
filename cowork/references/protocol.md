# Cowork protocol

Read this reference when initializing or mutating a Cowork workspace, running an
acceptance round, handling a missed turn or dispute, or recovering interrupted state.

## Generated layout

```text
.agents/cowork/
|-- STATE.md
|-- TASK.md
|-- CHAT.md
|-- PROTOCOL.md
|-- validate-state.sh
|-- claim-turn.sh
|-- watch-turn.sh
|-- advance-turn.sh
|-- roster-change.sh
|-- review-round.sh
|-- review-summary.sh
|-- select-questioner.sh
`-- agents/
    `-- <agent-id>/
        |-- PROMPT.md
        `-- NOTES.md
```

`STATE.md` is the sole live coordination state. `TASK.md` contains current owner
authorization, acceptance policy, launch allowlist, and queue. `CHAT.md` is the
append-only evidence and handoff history. The copied protocol makes the workspace
self-contained. Personal notes are scratch, never authority or secret storage.

## Authority and sequential safety

Current owner instructions, repository rules, and enforced permissions remain above
all Cowork files. Membership, provider, decision role, response count, rating, or
selection as questioner grants no external permission.

Exactly one verified lease holder writes shared or task files. `Turn` says who may
claim; the exclusive state lock serializes claims and management operations. An
arbitrary number of participants does not create parallel writers.

Codex and Claude participants have `Authority-<id>: decision`; other providers are
`advisory`. An evidence-backed disposition by either decision participant is accepted
by advisory participants. Only the owner, governing safety rules, or new concrete
evidence may reopen it. Decision authority never expands scope. When no decision
participant is available, unresolved decisions go to the owner.

The coordinator records `Provider-<id>` from the owner-authorized roster; a
participant does not self-assign it. Provider and authority fields are durable
coordination policy, not authentication or a security boundary.

## Version 2 state

Keep one key and value per line. Identifiers use lowercase ASCII letters, digits,
underscores, and hyphens, beginning with a letter or digit. Comma lists contain no
spaces or duplicates.

```text
Protocol-version: 2
Workstream: example
Status: SETUP
Turn: codex
Turn-session: any
Round: 0
Lease: none
Updated: 2030-01-02 03:04:05 +0000
Last-entry: none
Agents: codex,claude,deepseek
Coordinator: codex
Manager: none
Provider-codex: codex
Authority-codex: decision
Mode-codex: persistent
Session-codex: any
Rating-codex: R0/pending/none
Provider-claude: claude
Authority-claude: decision
Mode-claude: persistent
Session-claude: any
Rating-claude: R0/pending/none
Provider-deepseek: deepseek
Authority-deepseek: advisory
Mode-deepseek: turn
Session-deepseek: any
Rating-deepseek: R0/pending/none
Order-policy: queue
Order: codex,claude,deepseek
Order-index: 0
Turn-timeout-seconds: 0
Turn-deadline: 0
Review-round: 0
Reviewers: none
Review-deadline: 0
Review-target: 3
Review-minimum: 1
Questioner: none
Dispute-entry: none
Launch-mode: manual
Auto-launch: none
Auto-launch-limit: 0
Resume-after-owner: none
Question-entry: none
Poll-seconds: 60
Max-wait-seconds: 3600
```

Every identifier in `Agents` has exactly one provider, authority, mode, session, and
rating field. Provider identifiers are descriptive lowercase identifiers. Provider
`codex` or `claude` requires authority `decision`; every other provider requires
`advisory`. Modes are `persistent` and `turn`. Session labels use letters, digits,
dots, underscores, colons, and hyphens, or `any`.

`Order` contains every active agent exactly once. `Order-policy` is `queue` or
`round-robin`; the zero-based `Order-index` points to the current ordered participant.
Queue handoffs name the next participant explicitly. Round-robin handoffs use the
next index.

Deadlines are `0` or Unix timestamps. They are scheduling checkpoints, never lease
expiry. Ratings use `R<round>/<value>/<entry>`. Participant values are `pending`,
`approve`, `notes`, `object`, and `abstain`; `no-response` and `resolved-object` are
system dispositions that must point to the chat evidence which created them.

Allowed statuses:

- `SETUP`: only the coordinator prepares the task and initial state;
- `READY`: no lease exists and the addressed participant may claim;
- `WORKING`: exactly the verified lease holder may write;
- `OWNER_INPUT`: all participants stop for the referenced owner question;
- `FINAL`: all participants stop; the workstream is closed.

`Turn` is a roster identifier while active and `owner` in stop states. Every
participant refuses an unknown or missing protocol version. A v2 skill never edits a
v1 workspace in place.

## Setup

Before leaving `SETUP`, complete `TASK.md` with:

- objective, scope, exclusions, side-effect boundaries, and acceptance evidence;
- participant providers, roles, modes, observed sessions, coordinator, optional
  manager, and explicit order;
- queue steps and assigned owners;
- turn/review deadline policy, quality target, blocking minimum, and what happens
  when coverage is reduced;
- `manual` or `automatic` launch mode; automatic mode additionally lists exact
  `Auto-launch` identifiers and a positive `Auto-launch-limit` no larger than that
  list;
- known decisions, assumptions, and required validation.

Append setup entry `M0001`, then use the state lock and atomic replacement to change
state to `READY`, retaining the coordinator as `Turn`, routing its session, and
keeping `Lease: none`. Claim only after this transition.

## Claims and atomic state

Run:

```sh
.agents/cowork/claim-turn.sh <agent-id> <session-label>
```

The helper validates protocol, roster, status, turn, session, and empty lease under
an exclusive `.STATE.lock`; writes a session-unique lease via same-directory temporary
file and rename; then reads back the exact lease. Work begins only after `CLAIMED`.
While held, `.STATE.lock/owner` records agent, session, PID, and acquisition time.

All other live-state changes follow the same transaction:

1. acquire `.STATE.lock`, or invoke a helper that does;
2. reread and validate the complete state under the lock;
3. verify the caller's exact live lease when the operation requires one;
4. write a complete same-directory temporary file and rename it over `STATE.md`;
5. read back changed keys, then remove only the caller's owner record and lock.

Never truncate or source state, use `eval`, or infer ownership from timestamp age.
The watcher retries bad snapshots only as a fallback; it does not make in-place writes
safe.

`validate-state.sh` checks the complete protocol-2 roster and cross-field invariants.
Mutation helpers invoke it while holding the state lock; snapshot readers invoke it
on their private copy. Run it directly for diagnostics only, because a standalone
successful read does not acquire a lease or authorize a later write.

## Chat entries and response counts

Never rewrite active chat history. Every participant entry uses an ascending ID and
explicit machine-readable author:

```markdown
## M0042 — 2030-01-02 03:10 +0000 — handoff

- Author: deepseek
- Kind: handoff
- Review-round: none
- Rating: none
- Operation: queue step 7.
- Outcome: concise result.
- Evidence: commands or observations and their limits.
- Concerns: none, or specific unresolved risks.
- Next: one bounded operation and participant.
```

Kinds include `handoff`, `finding`, `rebuttal`, `rating`, `decision`, `missed-turn`,
`dispute`, and `owner-answer`. A response count is the number of well-formed entries
whose `Author` is that participant. Initializer and owner entries do not count. Counts
are descriptive and never affect authority, order, or acceptance.

`Rating` is `none` unless the entry is the evidence address stored in a
`Rating-<id>` field. A participant vote uses its exact value (`approve`, `notes`,
`object`, or `abstain`); a review-timeout entry uses `no-response`; and a decision
entry resolving an advisory object uses `resolved-object`. Those disposition entries
also name the active numeric `Review-round`, even though their `Kind` is
`missed-turn` or `decision` rather than `rating`.

## Turn selection, handoff, and missed turns

The lease holder hands off with:

```sh
.agents/cowork/advance-turn.sh handoff \
  <agent-id> <session-label> <next-agent-or-auto> <chat-entry>
```

Under `queue`, name the next agent. Under `round-robin`, use `auto`; the helper
advances `Order-index`. It resets status to `READY`, clears the lease, routes the next
session, increments `Round`, records `Last-entry`, and calculates `Turn-deadline`
from `Turn-timeout-seconds`.

If an unclaimed `READY` turn passes its nonzero deadline, only the coordinator may
append a `missed-turn` entry and run:

```sh
.agents/cowork/advance-turn.sh skip \
  <coordinator-id> <session-label> <next-agent-or-auto> <chat-entry>
```

Under `queue`, `next-agent` must name the explicit replacement; `auto` is valid only
under `round-robin`.

The state lock serializes this with a late claim. A `WORKING` deadline never permits
skip: confirm through the recorded lease/session that the process ended or ask the
owner. If the coordinator is unavailable, the owner names a replacement; another
participant never self-promotes.

## Roster changes

Membership and order are frozen during an active review (`Reviewers` is not `none`).
With owner authorization recorded in chat, the coordinator claims a normal turn and
uses one of:

```sh
.agents/cowork/roster-change.sh \
  <coordinator-id> <session-label> <owner-entry> add \
  'agent-id,provider,mode,session'

.agents/cowork/roster-change.sh \
  <coordinator-id> <session-label> <owner-entry> remove <agent-id>

.agents/cowork/roster-change.sh \
  <coordinator-id> <session-label> <owner-entry> reorder <comma-order>
```

The helper verifies the coordinator's live lease and updates every dependent field
atomically. It derives decision/advisory authority from provider. It refuses removal
of the coordinator or current turn holder. A join affects the next review. Finish or
explicitly abort a review before changing membership; a departed participant's
historical finding remains evidence.

## Review rounds and acceptance

An acceptance round snapshots `Order` into `Reviewers`, rotating its first position
by one from the prior round; increments `Review-round`; resets each snapshotted
rating; and sets `Review-deadline`. Record the exact review order in chat. Review is
an explicit queue operation, not a consequence of every handoff.

The coordinator opens it from a verified lease:

```sh
.agents/cowork/review-round.sh open \
  <coordinator-id> <session-label> <deadline-epoch> <chat-entry>
```

Each reviewer appends one independent evidence-bearing rating entry and atomically
sets `Rating-<id>` to `R<round>/<value>/<entry>`. It must not merely concur with an
earlier rating. Before the deadline, missing ratings keep the round open. Afterwards
the coordinator records each as `no-response`; silence is never forged into
`abstain`.

```sh
.agents/cowork/review-round.sh rate \
  <agent-id> <session-label> <approve|notes|object|abstain> <chat-entry>

.agents/cowork/review-round.sh timeout \
  <coordinator-id> <session-label> auto <chat-entry>
```

Before `timeout`, append its `missed-turn` evidence entry with the active
`Review-round` and `Rating: no-response`; the helper uses that entry for every
pending reviewer it marks. Before `resolve`, append a `decision` entry with the
active round and `Rating: resolved-object`. `review-summary.sh` validates these
machine-readable evidence links before accepting the round.

An advisory `object` remains blocking until fixed and rerated, or until Codex or
Claude records an evidence-backed disposition and changes its aggregate state to
`resolved-object`. An object from a decision participant requires another decision
participant or the owner to resolve it.

```sh
.agents/cowork/review-round.sh resolve \
  <codex-or-claude-id> <session-label> <advisory-agent-id> <chat-entry>
```

After recording the summary evidence, the coordinator closes the snapshot while
retaining its verified lease. `complete` reruns the read-only summary and refuses to
close unless it accepts; `abort` closes a rejected or superseded round without
pretending it passed. The coordinator then performs the next explicit state
transition or handoff.

```sh
.agents/cowork/review-round.sh close \
  <coordinator-id> <session-label> <complete|abort> <chat-entry>
```

Acceptance requires:

- one terminal state for every snapshotted reviewer;
- no unresolved `object`;
- at least `Review-minimum` `approve` or `notes` ratings;
- at least one `approve` or `notes` from a decision participant.

The default quality target is `min(3, reviewer-count)` and the default blocking
minimum is 1, matching the owner's rule that a Codex or Claude decision is accepted.
Missing the target is reduced coverage, not hidden unanimity. If no decision
participant is available or the minimum is unmet, enter `OWNER_INPUT`.

Run `.agents/cowork/review-summary.sh` to print counts, ratings, blockers, decision
coverage, target coverage, and the computed result. The helper is read-only; use the
explicit `close` operation rather than editing the active snapshot by hand.
Deterministic synthetic-roster tests do not prove real provider availability,
independent judgments, or cost.

## Disputes and questioner selection

When disagreement has no concrete next change, the current lease holder records a
`dispute` entry, then runs:

```sh
.agents/cowork/select-questioner.sh \
  <agent-id> <session-label> <dispute-entry>
```

The helper selects `Manager` when configured. Otherwise it randomly chooses among
active Codex/Claude decision participants; if none exist, it randomly chooses from
the roster. One locked transaction records `Questioner` and either retains the
selected caller's lease or hands off to the selected participant. All others wait.

The questioner writes one neutral question containing the competing positions,
evidence, and concrete alternatives; atomically sets `OWNER_INPUT`, `Turn: owner`,
`Lease: none`, and `Question-entry`; then stops. Random selection assigns only the
communication duty. After the owner responds, `Resume-after-owner` identifies who
records the answer and returns state through `READY` before claiming.

## Watcher and participant modes

Persistent participants run:

```sh
.agents/cowork/watch-turn.sh <agent-id> <session-label>
```

The watcher resolves state beside itself, validates version, membership, session,
status, and timing, and does not evaluate state as code. Environment overrides:

- `COWORK_POLL_SECONDS` overrides `Poll-seconds`;
- `COWORK_MAX_WAIT_SECONDS` overrides `Max-wait-seconds`;
- `COWORK_MAX_BAD_READS` defaults to 3 consecutive malformed/missing snapshots.

`ACT` means reread and attempt a claim. `STOP` means owner input or final. `CHECK`
means inspect liveness without stealing a lease. `OTHER_SESSION` means the turn is
routed to a different process. A turn-mode participant exits after handoff and is
invoked only for its task or rating, never merely to observe.

Common helper exits:

| Code | Meaning |
| --- | --- |
| 0 | requested operation or acceptance result succeeded |
| 64 | invalid arguments, identifier, roster, or numeric configuration |
| 65 | malformed or inconsistent state/chat |
| 66 | required file remained missing or unreadable |
| 73 | unsafe path, existing workspace, lock, or local storage failure |
| 75 | retry, wait, missed acceptance floor, or liveness check; no ownership gained |
| 76 | turn is routed to another session |
| 77 | review has an unresolved blocking object |
| 78 | unsupported protocol version |
| 130 | helper interrupted by `HUP`, `INT`, or `TERM` |

## Recovery, final, and migration

Never infer abandonment from age alone. Inspect the recorded lease/session or
`.STATE.lock/owner`; a missing owner record makes a lock unattributed, not safe to
remove. Record evidence that the exact process ended before the selected recovery
participant removes the exact stale lock. Ask the owner when uncertain.

Malformed state, duplicate writers, inconsistent membership/order/review fields, or
an unsupported version stop mutation. Preserve evidence and ask which state survives.

Final reports what was verified and what was not. It never commits, publishes,
deploys, or cleans up without separate authorization. Preserve a final workspace
under an ignored history path before initializing another.

Protocol 2 refuses protocol 1. An active v1 workspace finishes with its already
copied v1 protocol and helpers, or is archived before initializing v2. Do not silently
migrate it; no migration helper is shipped without a real authorized migration case.
