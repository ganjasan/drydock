## Why

Drydock exists to be the universal, domain-agnostic core of the methodology that APZ currently embodies inside the Apilize monorepo. Today every command, skill, and agent lives in `apilize-hub/plugins/apz/` and is riddled with Apilize-specific paths, labels, GitHub Project IDs, and multi-repo workspace assumptions. Without a port, Drydock is an empty shell: the `docs/` promise a `/dd:*` command family that does not exist, and any external user installing the plugin finds `commands/`, `skills/`, and `agents/` directories containing only READMEs. This change delivers the v0.1 command suite so Drydock becomes usable standalone, and so APZ can subsequently thin itself down to Apilize-only additions.

## What Changes

- Add the `/dd:status` and `/dd:next` top-level commands (universal, no Apilize dependencies).
- Add the `/dd:req:*` family: `vision`, `use-case`, `stakeholder`, `adr`, `review`, `elicit`. All defaults resolve against `<repo>/requirements/…` instead of `apilize-hub/requirements/…`.
- Add the `/dd:build:*` family: `start`, `explore`, `design`, `code`, `test`. `start` operates on the current repo instead of routing through an `area_to_repo` table; when multi-repo routing is desired, callers configure it via plugin settings.
- Add the `/dd:ship:*` family: `pr`, `archive`, `release`. Deliberately **exclude** `conformance` and `parity` — they remain in APZ because they are Apilize-Protocol-specific.
- Add the `/dd:plan:*` family: `add`, `triage`, `promote`. GitHub Project ID, label names, and Area→repo mapping become plugin configuration rather than hardcoded Apilize values.
- Add reusable skills under `skills/`: `vision-and-scope`, `use-case`, `stakeholder-profile`, `requirements-elicitation`, `requirements-review`, `adr`, `openspec-new-change`, `openspec-continue-change`, `openspec-apply-change`, `openspec-ff-change`, `openspec-explore`, `openspec-verify-change`, `openspec-archive-change`, `openspec-sync-specs`, `openspec-bulk-archive`. Each is standalone-invokable.
- Add subagents under `agents/`: `code-reviewer`, `code-explorer`, `code-architect`, `traces-linter`, `release-coordinator`. `raw-classifier` stays in APZ.
- Add a `plugin.json` manifest at the repo root declaring the Drydock plugin, its commands, agents, and skills. Add a `config.yaml.example` documenting the configurable knobs (project ID, area→repo map, branch naming, worktree policy) so consumers can opt in to multi-repo workflows.
- **BREAKING:** None for external users (v0.1 is a green-field release). For APZ users, see `docs/migration-from-apz.md` — command names change one-for-one and hardcoded Apilize paths are replaced with configurable defaults. The rename is intentional and not backward-compatible per the "Do not" rule in `CLAUDE.md`.
- Raw-content ingestion (`/apz:raw:*`) is explicitly **out of scope**. Those commands depend on Apilize-hub-only directory structure and external tracker integrations and stay in APZ.

## Capabilities

### New Capabilities

- `command-suite`: The `/dd:*` slash-command family covering status, next, requirements, build, ship, and plan phases. Defines each command's argument shape, procedure, configuration hooks, and guardrails.
- `skill-library`: The set of Drydock skills (`vision-and-scope`, `use-case`, `stakeholder-profile`, `requirements-elicitation`, `requirements-review`, `adr`, and the `openspec-*` skills). Defines standalone-invokability, directory layout, template/example conventions, and the contract between skills and their command wrappers.
- `agent-library`: The set of Drydock subagents (`code-reviewer`, `code-explorer`, `code-architect`, `traces-linter`, `release-coordinator`). Defines each agent's trigger conditions, allowed tools, and output contract.
- `plugin-manifest`: The Claude Code plugin declaration (`plugin.json`) and user-facing configuration (`config.yaml`). Defines discoverability, where configuration is read from, and which knobs exist (project ID, area→repo map, branch/worktree conventions, labels).

### Modified Capabilities

None. `openspec/specs/` currently contains only a README, so there are no existing specs whose requirements change.

## Impact

- **New directories populated**: `commands/{status,next}.md`, `commands/req/*.md`, `commands/build/*.md`, `commands/ship/*.md`, `commands/plan/*.md`; `skills/<name>/SKILL.md` (15 skills); `agents/*.md` (5 agents).
- **New root files**: `plugin.json`, `config.yaml.example`.
- **Docs touched**: `docs/migration-from-apz.md` flips from "roadmap for v0.1" to "final mapping"; `docs/skills-catalog.md` references become live; `commands/README.md`, `skills/README.md`, `agents/README.md` get updated to point at real files.
- **APIs / external systems**: depends on `gh` CLI (GitHub Issues, PRs, Projects v2), `openspec` CLI, local git worktrees. No new external deps.
- **Downstream**: APZ must, in a follow-up release, be refactored to depend on Drydock and keep only Apilize-specific additions (raw ingestion, conformance, parity). That refactor is **not** part of this change but is the motivating follow-up.
- **Risk**: the port is large (≈30 command files, 15 skills, 5 agents). Mitigation: this change is broken into sub-capabilities so command-suite can land independently of skill-library where useful, and the `tasks.md` will sequence in phases (status/next first, then req, then build, then ship, then plan) so progress is verifiable incrementally.
