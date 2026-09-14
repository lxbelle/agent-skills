# Agent Skills

Portable skills for agents working with project files. One shared source per skill;
no mandatory framework, plugin, model provider or installed package set.

| Skill | Purpose | Version |
| --- | --- | --- |
| [startup](startup/SKILL.md) | Initialize or reconcile resumable project coordination, delegation transports and role-local implementation, TDD, debugging and review methods | 1.5.0 |
| [design](design/SKILL.md) | Design, implement, review, or refine platform-appropriate product interfaces | 0.1.0 |
| [cowork](cowork/SKILL.md) | Run any-size model roster through safe sequential turns, evidence-backed ratings and explicit stops | 0.2.0 |

## Requirements and scope

The skills use the common [Agent Skills format](https://agentskills.io/specification).
The client must read instructions, access the target project with permission and
persist files. Verification uses available project tools; no runtime packages are
bundled. Delegation uses the host's native subagents, an authorized command-line
worker that the manager launches non-interactively (for example `codex exec` or
`claude -p`), or an explicit manual handoff; none is mandatory. Startup ships a
reference Codex launcher in `startup/scripts/` that a project copies into its
`.agents/bin/`. A model in a chat-only host cannot initialize an
inaccessible filesystem. Format portability is not a guarantee for every model or
client.

Startup initializes the agent layer, not application code, dependencies or a
deployment. Existing project decisions, user edits and pauses remain binding.

Design guides product-interface creation, implementation and review across desktop,
web, iOS and Android. It provides no UI framework, fixed visual style or marketing
page template; platform-specific guidance applies only to its target.

Cowork coordinates an arbitrary-size model roster on one existing repository task
through one verified writer, explicit order, append-only evidence, response counts,
per-model ratings and optional low-frequency watchers. Codex and Claude carry the
owner-selected decision priority; other providers remain advisory. It does not grant
permissions, initialize Startup or promise automatic launch when the host lacks a
configured interface and exact participant allowlist.

## Install one skill

Review the source first. Copy one selected skill directory—`startup/`, `design/`, or
`cowork/`—into **one** selected skill location. Keep its complete contents, including
licenses, notices, references and scripts. Do not copy the whole repository. Compare
versions and preserve local changes before overwriting an existing installation.

These are primary **personal, local-machine** locations. Each link documents
project-scoped alternatives; choose one scope per client instead of duplicates.
Routes follow the official documentation linked below.

| Client | Primary destination | Documentation |
| --- | --- | --- |
| Codex | `~/.agents/skills/<skill-name>/SKILL.md` | [Skills and local discovery](https://learn.chatgpt.com/docs/build-skills) |
| Claude Code | `~/.claude/skills/<skill-name>/SKILL.md` | [Skill locations](https://code.claude.com/docs/en/skills#where-skills-live) |
| Gemini CLI | `~/.gemini/skills/<skill-name>/SKILL.md` | [Discovery and installation](https://geminicli.com/docs/cli/using-agent-skills/) |
| GitHub Copilot | `~/.copilot/skills/<skill-name>/SKILL.md` | [Skills and supported surfaces](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills) |
| Cursor | `~/.cursor/skills/<skill-name>/SKILL.md` | [Skill directories](https://cursor.com/docs/skills) |

Here `~` means your user profile, not a path inside this repository. Confirm the
actual client's discovery location; older/local Codex setups may expose
`~/.codex/skills` instead. Replace `<skill-name>` with `startup`, `design`, or
`cowork`, reload or restart as the client requires, and verify that the selected
skill appears before claiming installation succeeded.

GUI upload/install and CLI filesystem discovery are different delivery methods.
Local personal folders do not automatically reach remote/cloud agents; use the
selected surface's documented project or account installation. Preserve consent
prompts. No universal installer, plugin manifest or automatic global-config change
is required here. For an unlisted client, verify its skill support or explicitly
provide the source file; manual reading is not a discovery test.

## Invoke a skill

Cowork is intended for an explicit request to start or resume a sequential roster:

> Use our cowork skill for this task with Codex, Claude and DeepSeek. Launch mode is
> manual; I will start the models. Use that explicit order, collect a short rating
> and response count from each model, and stop on final or one question for me.

For automatic use, say `launch mode: automatic` instead. The initiating agent
creates `.agents/cowork/`, records the task, roster, boundaries, order and selected
mode, then either waits for owner-started participants or starts only exact allowlisted
participants through an already configured interface. If no mode was specified, it
asks before launching. Cowork never enables dangerous bypass flags or enlarges any
participant's authorization.

Design can be selected implicitly for interface work or named directly:

> Use our design skill to design and implement this interface. Preserve the
> product's existing constraints and make the result native to its target platform.

If a host also provides a skill named `design`, verify that it selected this
package by its source or description; otherwise name the installed package path
explicitly in the request.

When multiple concepts are requested, the skill requires structural variation, not
one layout recolored several ways. Its supporting references are read only for the
visual, accessibility, adaptive-platform or interaction concerns in the task.

### Startup invocation and resume

Explicit first-use request (select `startup` in the client's skill UI, or use
`/startup` in Claude Code):

> Use the startup skill to initialize the manager for `/path/to/project`.
> Preserve existing instructions, decisions and pauses. Create or reconcile
> the agent layer and role-local methods; do not start product implementation.

Without installation, explicitly ask the agent to read this checkout's
`startup/SKILL.md` before doing that work. Implicit selection can match requests
to initialize/reconcile the agent workspace; the description excludes ordinary
implementation, application startup and deployment. Do not assume matching worked:
confirm the skill was selected or name it explicitly.

Installation does **not** restore a project session. After setup, new managers
follow the target project's router and current state, not this repository's files:

| Selected client | Target-project entry |
| --- | --- |
| Codex | Applicable [AGENTS.md chain](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| Claude Code | Preserve `CLAUDE.md`; add `@AGENTS.md` import when needed. [Memory bridge](https://code.claude.com/docs/en/memory#agentsmd) |
| Gemini CLI | Preserve `GEMINI.md`; add `@./AGENTS.md` import, or retain existing context-file configuration. [Context imports](https://geminicli.com/docs/cli/gemini-md/) |
| Other clients | Verify the native project entry or explicitly instruct the session to read `AGENTS.md`; this fallback is manual |

Add bridges only for clients actually selected. They route to one set of rules,
not copies. Each worker needs the applicable router constraints, ordered role
chain, task packet and authorized inputs; `ROLE.md`, `Reads` and `Uses` are file
conventions, not native subagent registration. Some workers omit project memory.
[Claude subagent context](https://code.claude.com/docs/en/sub-agents#what-loads-at-startup)

## Generated files and lifecycle

Cowork creates local task, state, chat, protocol, deterministic turn/roster/review
helpers, watcher, prompt and notes files under the target project's `.agents/cowork/`
or its established private equivalent.
It preserves a final workstream before starting another and never treats personal
notes or historical chat as current authority. Projects decide whether this local
coordination area is ignored or intentionally tracked.

Startup authors an `AGENTS.md` router and private `.agents/` rules, state, base
roles and task packets as needed, preserving equivalent existing layouts. Human
specifications and decisions stay in the project's public documentation, normally
`docs/` or its established location. Public contribution must work without private
coordination files. Private records are local by default, not secret storage.

Project-local role methods remain sufficient without Startup or Superpowers.
Updating an installed skill affects future applications, not existing projects:
request reconciliation explicitly and preserve live assignments. Uninstall only
the selected installation through the client's mechanism; do not delete generated
project rules, state or work. Removing other global skills is a separate decision.

## Package and verification

The public package consists of `.gitignore`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
`LICENSE`, and the complete `startup/`, `design/`, and `cowork/` directories. Each
bundled MIT license matches the root notice for standalone distribution; `design/`
also retains its third-party notices and Apache-2.0 license copy. Local chats,
research, historical specifications, templates, fixtures and caches live under
ignored `.agents/`.
Keep local working material there rather than inside public skill directories.
Inspect selected files before staging/publication; never force-add private files.

Maintain format, release composition, client discovery and observed behavior as
separate results. Use an already available standard-compatible validator (for
example `skills-ref validate startup`); do not install tooling implicitly. Also
review local links, the source diff and `git diff --check`. Untracked files need
explicit inspection; an empty Git diff is not evidence they were checked.

## License and publication

Original repository material is licensed under the [MIT License](LICENSE): copying,
modification, redistribution, commercial use and sublicensing are permitted,
provided the copyright and license notice are retained. The work is provided without
warranty. Each standalone skill includes the same notice in its `LICENSE` file. The
design skill also contains
[third-party notices](design/THIRD_PARTY_NOTICES.md) for adapted MIT and Apache-2.0
material; redistributed copies must retain them and the referenced license text.

Repository destination and visibility remain owner choices. Preparing these files
does not authorize staging, committing, configuring identity or credentials,
adding a remote, publishing or pushing.
