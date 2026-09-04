# Launching and supervision

Read this reference when selecting, starting, checking, resuming, or stopping one or
more Cowork participant processes.

## Launch authority

`Launch-mode` is owner-selected:

- `manual`: prepare participant prompts and exact paths or commands; only the owner
  starts the model processes;
- `automatic`: start only identifiers in `Auto-launch`, never beyond
  `Auto-launch-limit`, through an already configured interface;
- `unset`: start nobody and ask the owner to choose.

An arbitrary roster size is not launch authorization. `Auto-launch` must enumerate
exact participant identifiers; adding a member does not launch it. If the requested
automatic interface is unavailable, ask before changing mode. Repository rules may
require manual launch.

Launch mode and participant mode are separate. `persistent` means an observed live
session remains with a low-frequency watcher. `turn` means the participant is invoked
only for its assigned task or rating, reconstructs context from files, hands off, and
exits. Never invoke a model merely to observe.

## Capability and cost check

Before an automatic launch:

1. verify the exact participant is in `Agents` and `Auto-launch`, and that the launch
   count remains within `Auto-launch-limit`;
2. inspect the host's existing agent/session interface or installed CLI help for
   current background, working-directory, naming, resume, and permission options;
3. give the participant its generated `agents/<id>/PROMPT.md` and the common
   repository root rather than embedding untrusted task text in a command;
4. preserve sandbox, approval, model, billing, and credential settings;
5. record the observed process/session identifier before marking it persistent.

Do not install a launcher, authenticate, alter credentials or billing, select an
unrequested paid service, pass secrets through prompts, use permission-bypass flags,
or construct commands with `eval` or unquoted task text.

Large rosters should normally keep only the coordinator and actively collaborating
participants persistent. Turn-mode participants are started only when `Turn` or a
review snapshot requires them. A review round asks each reviewer once; it does not
keep waking the whole roster.

## Launch routes

Use the first route actually supported by the environment.

### Host-native persistent agent

Use a host API or session manager that gives the participant the same workspace and
can preserve its session. One-turn subagents are valid only for participants recorded
as `turn`; do not describe them as persistent.

### Local background or managed terminal

Check installed help rather than assuming flags. When Claude Code exposes `--bg` and
`--name`, a command may have this shape:

```sh
claude --bg --name cowork-claude \
  "Read /absolute/repository/.agents/cowork/agents/claude/PROMPT.md and follow it."
```

When an installed Codex CLI exposes `-C`, a host-managed persistent terminal may use:

```sh
codex -C /absolute/repository \
  "Read .agents/cowork/agents/codex/PROMPT.md and follow it."
```

These are conditional shapes, not proof of availability. Retain current permissions,
capture the returned identifier, and never start participants absent from the exact
allowlist.

### Manual launch

Provide the owner one exact command or generated prompt path per participant needed
now. Persistent participants can then alternate without owner relay. A turn-mode
participant necessarily requires a later owner or authorized launcher invocation;
record that limitation instead of implying continuous availability.

## Supervision and stop states

Each process supervises only its own session and watcher. Quiet watchers are expected.
On `CHECK`, inspect the exact recorded session; do not replace a live lease holder.
On an expired unclaimed turn, follow the coordinator skip rule. On `OWNER_INPUT` or
`FINAL`, every participant ends normally.

When a dispute selects `Questioner`, all other participants wait. Only that
participant composes the owner question; after it sets `OWNER_INPUT`, it stops too.

Force termination only for a confirmed duplicate or wedged exact process, and
preserve state/chat evidence. No stop state authorizes unrelated cleanup.
