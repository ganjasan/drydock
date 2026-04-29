# Skills Catalog

Drydock ships (pun intended) a small, curated set of skills. Each skill is reusable across commands and can also be invoked directly by name (`/<skill>`) without going through a `/dd:*` wrapper.

Skills follow the Claude Code Skill convention: a `SKILL.md` with YAML frontmatter (`name`, `description`, optional `allowed-tools`) and the body of the skill prompt. Each lives at `skills/<name>/SKILL.md`.

## Requirements skills

### vision-and-scope

Create a Wiegers-style Vision & Scope document. Wrapped by `/dd:req:vision`. File: `skills/vision-and-scope/SKILL.md` (with `templates/` and `examples/`).

### use-case

Write a Wiegers/Cockburn use case (primary actor, trigger, main success scenario, extensions, etc.). Wrapped by `/dd:req:use-case`. File: `skills/use-case/SKILL.md`.

### stakeholder-profile

Create detailed stakeholder profiles. Wrapped by `/dd:req:stakeholder`. File: `skills/stakeholder-profile/SKILL.md`.

### requirements-elicitation

Prepare an elicitation plan — gaps, stakeholders, techniques, schedule. Wrapped by `/dd:req:elicit`. File: `skills/requirements-elicitation/SKILL.md`.

### requirements-review

Review requirements against the eight Wiegers quality criteria (clear, complete, consistent, feasible, necessary, prioritized, testable, unambiguous). Wrapped by `/dd:req:review`. File: `skills/requirements-review/SKILL.md`.

### adr

Create an Architectural Decision Record with auto-numbering and traceability frontmatter. Wrapped by `/dd:req:adr`. File: `skills/adr/SKILL.md`.

## Raw skills

Shipped in v0.2 via the `add-raw-phase` OpenSpec change. Each skill is standalone-invokable; commands under `/dd:raw:*` are thin wrappers.

### raw-capture

Manual capture of an external signal into `<repo>/<paths.raw_root>/_incoming/` with structured frontmatter (source, dedup_key, captured_at, parties, topics, …). File: `skills/raw-capture/SKILL.md`. Wrapped by `/dd:raw:capture`.

### raw-process

Classify the inbox into `meetings/`, `feedback/`, `ideas/`, `competitors/`, `client-boards/` (defaults; customizable via `raw.classifier.categories`). Dedup by `dedup_key`; cross-link to existing requirements and open issues; suggest backlog items. Wrapped by `/dd:raw:process`. Invokes the `raw-classifier` subagent.

### raw-ingest-{gmail, calendar, drive, notion, linear, github}

One skill per source. Reads filter config from `<repo>/.drydock/config.yaml` under `raw.<source>.*`; pulls items via the corresponding MCP server (or `gh` CLI for `github`); writes to `_incoming/` with the universal frontmatter schema; fires `post-capture` hook per item. Wrapped by `/dd:raw:ingest-<source>`.

### raw-transcribe

Transcribe an audio/video file referenced in a raw entry's `attachments` (typically a Meet recording) and fold the transcript into the meetings subfolder. Provider and model come from `raw.transcribe.*` config. File: `skills/raw-transcribe/SKILL.md`. Wrapped by `/dd:raw:transcribe`.

## Build skills

### openspec-new-change

Create a new OpenSpec change with proposal/design/tasks skeleton. Used by `/dd:build:start` and standalone. File: `skills/openspec-new-change/SKILL.md`.

### openspec-continue-change

Advance an in-flight change to the next missing artifact. Used by `/dd:build:design`. File: `skills/openspec-continue-change/SKILL.md`.

### openspec-apply-change

Work through the tasks list of an active change. Used by `/dd:build:code`. File: `skills/openspec-apply-change/SKILL.md`.

### openspec-ff-change

Fast-forward — generate proposal/design/tasks/specs in one pass for well-understood work. Used by `/dd:build:ff`. File: `skills/openspec-ff-change/SKILL.md`.

### openspec-explore

Q&A mode for ambiguous scope. Used by `/dd:build:explore`. File: `skills/openspec-explore/SKILL.md`.

### openspec-verify-change

Pre-archive verification: tasks all checked, deltas consistent, design references resolve. Used by `/dd:build:verify` and indirectly by `/dd:ship:archive`. File: `skills/openspec-verify-change/SKILL.md`.

## Feature skills

Shipped in v0.2 via the `add-feature-orchestrator` OpenSpec change. Both skills are standalone-invokable; `/dd:feature` is a thin wrapper around the orchestrator.

### feature-orchestrate

Walk a single idea through all ten Drydock phases — raw capture → code exploration → structured clarification → issue + OpenSpec change → branch + worktree → architecture proposal → design + tasks → implementation loop → tests → draft PR. Pauses at each phase boundary per `feature.pause_after.<phase>` config (defaults: pause after `idea`, `clarify`, `design`, `pr`). Never reimplements per-phase logic — every phase delegates to the corresponding `/dd:raw:capture`, `/dd:plan:add`, `/dd:plan:promote`, `/dd:build:start`, `/dd:build:design`, `/dd:build:code`, `/dd:build:test`, `/dd:ship:pr`, or directly to `dd:code-explorer` / `dd:code-architect` agents. Stepping out at any pause leaves a recoverable workspace; the resume hint cites the per-phase command that picks up from there. Wrapped by `/dd:feature`. File: `skills/feature-orchestrate/SKILL.md`.

### feature-clarify

Run a closed-form structured clarifying-questions round. Each question has exactly one recommended answer, 2–4 named alternatives (each with a one-line reasoning hint), a `[d] discuss this further` option that opens `openspec-explore` for that thread, and a `[?] defer to design.md § Open Questions` option. Generated one at a time conditioned on prior answers; emits as many questions as the spec actually depends on (zero if the codebase + idea leave no ambiguity). Captured answers are appended to `<change>/proposal.md` § Context as `### Clarifying answers`; deferred ones land in `<change>/design.md` § Open Questions. Distinct from `openspec-explore` — that's a free-form thinking partner; this is structured Q&A whose output drops programmatically into OpenSpec artifacts. File: `skills/feature-clarify/SKILL.md`.

## Ship skills

### openspec-archive-change

Archive a completed change after merge. Used by `/dd:ship:archive`. File: `skills/openspec-archive-change/SKILL.md`.

### openspec-sync-specs

Sync delta specs from a change into main `openspec/specs/`. Called by `/dd:ship:archive`. File: `skills/openspec-sync-specs/SKILL.md`.

### openspec-bulk-archive

Archive multiple parallel completed changes in one pass. File: `skills/openspec-bulk-archive/SKILL.md`.

## Subagents (related, but not skills)

Subagents live under `agents/` and are invoked by commands and skills via the Agent tool.

- **code-reviewer** — reviews diffs against the active OpenSpec change's tasks and specs (Drydock-flavored — distinct from Claude Code's built-in code-reviewer).
- **code-explorer** — traces execution paths AND surfaces traceability artifacts (ADRs, use cases, vision sections).
- **code-architect** — produces designs in the shape of an OpenSpec `design.md` section.
- **traces-linter** — verifies bidirectional `traces_to` frontmatter references.
- **release-coordinator** — orchestrates multi-repo releases (only invoked when `config.yaml` declares dependent repos).
- **raw-classifier** — classifies items in `<raw_root>/_incoming/` into the configured category set; dedups; suggests cross-links. Read-only — does not move files. Invoked by the `raw-process` skill via `/dd:raw:process`. File: `agents/raw-classifier.md`.

## Conventions

- Skill directories are kebab-case under `skills/`.
- Each skill has a `SKILL.md` with `name`, `description`, optional `allowed-tools`, and the prompt body.
- Templates live in `<skill-name>/templates/`, examples in `<skill-name>/examples/`.
- Skills are **standalone-invokable**: command files are thin wrappers that pass arguments and resolve placement, not the source of the skill's logic.
