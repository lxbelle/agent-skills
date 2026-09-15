# Agent Skills repository

This is a collection of reusable skills, not a project already initialized by
Startup. Maintain the requested source; do not bootstrap this repository merely
because a skill is present.

## Index and reading routes

- [README.md](README.md): purpose, installation, lifecycle and release boundaries.
- [cowork/SKILL.md](cowork/SKILL.md): durable sequential model turns, roster launch,
  shared handoffs and owner/final stop conditions.
- [simple-design/SKILL.md](simple-design/SKILL.md): the portable product-interface design,
  implementation and review workflow, with conditional references.
- [mac-control/SKILL.md](mac-control/SKILL.md): background macOS GUI driving
  through cua-driver for Claude Code and Codex, with its shell helpers.
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

For Cowork, preserve sequential writers, one live turn and verified lease, an
identifier-keyed roster, project-local task/state/chat separation, per-agent
prompts, explicit order, launch and participant modes, low-frequency waiting,
evidence-backed ratings, response summaries, owner questions and final stops. Do not
cap the participant count or introduce parallel writers. Codex and Claude have the
owner-selected decision priority; an optional manager presents disputes, otherwise
one Codex/Claude participant—or any participant when neither exists—is randomly
selected as questioner while everyone else waits. Cowork coordinates an authorized
task but grants no new permissions and must not bootstrap Startup. Keep deterministic
state helpers portable and behaviorally tested; keep launcher-specific examples
conditional.

When developing skills in this repository, the owner launches the external peer
manually; repository agents must not start it. Keep that local development rule
distinct from Cowork's behavior in ordinary projects: each invocation records either
`manual` or `automatic` peer launch, and no agent infers automatic launch when the
mode was omitted.

For Design, preserve brief-specific art direction, genuinely divergent concepts,
desktop/web/iOS/Android platform routing, accessibility, adaptive behavior and
rendered review. Do not turn it into a marketing-page generator, fixed aesthetic,
framework prescription or speculative component library. Keep substantial
conditional guidance in `simple-design/references/` and retain third-party notices.

For Startup, preserve authority, public/private routing, pauses, exact writer and
launch identity, the three delegation transports, manager context economy, safe
recovery, report transport and acceptance versus integration.
Keep engineering methods project-local and routed by role. Do not weaken these
contracts to meet a line/token target. When the contract changes, update both
version metadata and its generated Built-from marker, then review README claims.

## Validation and publication

Use available validators and proportionate static inspection; report unavailable
checks, dependencies and evidence scope honestly. Fresh-agent tests need agreed
bounded scope and disposable workspaces. Format/discovery/behavior are different
claims; do not infer universal model support from valid Markdown.

Release files: `.gitignore`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
`LICENSE`, and the complete `startup/`, `simple-design/`, `mac-control/`, and `cowork/` directories. The
owner authorized the permissive MIT license. Keep each bundled skill `LICENSE`
identical to the root license so standalone distribution retains its notice; keep
Design's applicable third-party notices and license copies with it. Review the
selected files when adding a skill or public artifact. Keep local material under
`.agents/` instead of adding per-file ignore rules; never force-add it to Git.
Inspect selected contents and whitespace before a separately authorized commit. Git
identity, credentials, remote destination, visibility and publication remain
owner-controlled; do not configure or perform them implicitly.
