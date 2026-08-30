# Agent Skills

Portable, instruction-only skills for agents working with project files.
One shared source per skill; no mandatory framework, plugin or model provider.

| Skill | Purpose | Version |
| --- | --- | --- |
| [startup](startup/SKILL.md) | Initialize or reconcile resumable project coordination and role-local implementation, TDD, debugging and review methods | 1.4.0 |

## Requirements and scope

Startup uses the common [Agent Skills format](https://agentskills.io/specification).
The client must read instructions, access the target project with permission and
persist files. Verification uses available project tools; no runtime packages are
bundled. Native subagents are optional: unsupported delegation uses an explicit
manual handoff. A model in a chat-only host cannot initialize an inaccessible
filesystem. Format portability is not a guarantee for every model or client.

Startup initializes the agent layer, not application code, dependencies or a
deployment. Existing project decisions, user edits and pauses remain binding.

## Install one skill

Review the source first. Copy the `startup/` directory into **one** selected skill
location. It contains `SKILL.md` and `LICENSE`; keep the license notice with
redistributed copies. Do not copy the whole repository. Compare versions and
preserve local changes before overwriting an existing installation.

These are primary **personal, local-machine** locations. Each link documents
project-scoped alternatives; choose one scope per client instead of duplicates.
Routes follow the official documentation linked below.

| Client | Primary destination for this skill | Documentation |
| --- | --- | --- |
| Codex | `~/.agents/skills/startup/SKILL.md` | [Skills and local discovery](https://learn.chatgpt.com/docs/build-skills) |
| Claude Code | `~/.claude/skills/startup/SKILL.md` | [Skill locations](https://code.claude.com/docs/en/skills#where-skills-live) |
| Gemini CLI | `~/.gemini/skills/startup/SKILL.md` | [Discovery and installation](https://geminicli.com/docs/cli/using-agent-skills/) |
| GitHub Copilot | `~/.copilot/skills/startup/SKILL.md` | [Skills and supported surfaces](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills) |
| Cursor | `~/.cursor/skills/startup/SKILL.md` | [Skill directories](https://cursor.com/docs/skills) |

Here `~` means your user profile, not a path inside this repository. Confirm the
actual client's discovery location; older/local Codex setups may expose
`~/.codex/skills` instead. Reload or restart as the client requires and verify
that **startup** appears in its skill list before claiming installation succeeded.

GUI upload/install and CLI filesystem discovery are different delivery methods.
Local personal folders do not automatically reach remote/cloud agents; use the
selected surface's documented project or account installation. Preserve consent
prompts. No universal installer, plugin manifest or automatic global-config change
is required here. For an unlisted client, verify its skill support or explicitly
provide the source file; manual reading is not a discovery test.

## Invoke and resume

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
`LICENSE`, `startup/SKILL.md` and `startup/LICENSE`. The bundled license matches
the root notice for standalone distribution. Local chats, research, historical
specifications, templates, fixtures and caches live under ignored `.agents/`.
Keep local working material there rather than inside public skill directories.
Inspect selected files before staging/publication; never force-add private files.

Maintain format, release composition, client discovery and observed behavior as
separate results. Use an already available standard-compatible validator (for
example `skills-ref validate startup`); do not install tooling implicitly. Also
review local links, the source diff and `git diff --check`. Untracked files need
explicit inspection; an empty Git diff is not evidence they were checked.

## License and publication

Licensed under the [MIT License](LICENSE): copying, modification, redistribution,
commercial use and sublicensing are permitted, provided the copyright and license
notice are retained. The work is provided without warranty. The standalone skill
includes the same notice in [startup/LICENSE](startup/LICENSE).

Repository destination and visibility remain owner choices. Preparing these files
does not authorize staging, committing, configuring identity or credentials,
adding a remote, publishing or pushing.
