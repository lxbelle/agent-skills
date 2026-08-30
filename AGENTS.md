# Agent Skills repository

This is a collection of reusable skills, not a project already initialized by
Startup. Maintain the requested source; do not bootstrap this repository merely
because a skill is present.

## Index and reading routes

- [README.md](README.md): purpose, installation, lifecycle and release boundaries.
- [startup/SKILL.md](startup/SKILL.md): the authoritative Startup runtime contract.
  Read it completely when editing or applying Startup, not for unrelated work.
- [CLAUDE.md](CLAUDE.md): a thin import of this file, not a second instruction set.

Local chats, research, historical specifications, templates and fixtures belong
inside ignored `.agents/`, not skill packages. They are not public dependencies or
current authority by default. Read them only when needed; distinguish historical
proposals from current user authorization.

## Maintaining a skill

Keep one source in `<skill-name>/SKILL.md`, with common YAML frontmatter and a
matching directory/name. Prefer concise, model-independent instructions and
capability checks to vendor hooks, model pins, duplicated client variants or
implicit tool installation. Keep host-specific extensions optional.

For Startup, preserve authority, public/private routing, pauses, exact writer and
launch identity, safe recovery, report transport and acceptance versus integration.
Keep engineering methods project-local and routed by role. Do not weaken these
contracts to meet a line/token target. When the contract changes, update both
version metadata and its generated Built-from marker, then review README claims.

## Validation and publication

Use available validators and proportionate static inspection; report unavailable
checks, dependencies and evidence scope honestly. Fresh-agent tests need agreed
bounded scope and disposable workspaces. Format/discovery/behavior are different
claims; do not infer universal model support from valid Markdown.

Release files: `.gitignore`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
`LICENSE`, `startup/SKILL.md`, and `startup/LICENSE`. The owner authorized the
permissive MIT license. Keep the bundled `startup/LICENSE` identical to the root
license so standalone distribution retains its notice. Review the selected files
when adding a skill or public artifact. Keep local material under `.agents/`
instead of adding per-file ignore rules; never force-add it to Git.
Inspect selected contents and whitespace before a separately authorized commit.
Git identity, credentials, remote destination, visibility and publication remain
owner-controlled; do not configure or perform them implicitly.
