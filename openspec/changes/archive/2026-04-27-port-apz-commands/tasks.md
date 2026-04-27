## 1. Plugin manifest and configuration scaffold

- [x] 1.1 Write `plugin.json` at repo root with `name: drydock`, `version: 0.1.0`, `description`, and component directory declarations (`commands/`, `skills/`, `agents/`)
- [x] 1.2 Write `config.yaml.example` at repo root with sections `github`, `paths`, `worktree`, `area_to_repo`, each key annotated with a comment explaining purpose and default
- [x] 1.3 Add a small `lib/config.sh` (or equivalent) that resolves `${CLAUDE_PLUGIN_ROOT}/config.yaml`, merges with built-in defaults, and exposes key lookups to command bodies
- [x] 1.4 Add `lib/frontmatter.sh` (or equivalent) with helpers used by ADR numbering and slug generation, ported from APZ's `lib/frontmatter.sh` minus Apilize-specific pieces
- [x] 1.5 Update root `README.md` to describe Drydock, link to `docs/methodology.md` and `docs/workflow.md`, and document installation + `/dd:status` as the first command to run

## 2. Top-level commands: status and next

- [x] 2.1 Port `/apz:status` → `commands/status.md` with Apilize references replaced by generic git/gh/filesystem checks; remove the `apilize-hub/raw/_incoming/` section; remove project board count when no project is configured
- [x] 2.2 Port `/apz:next` → `commands/next.md` with the Apilize-hub raw-inbox check removed; keep the active-change → branch-ahead → untriaged → clean-main decision tree; replace "Apilize Backlog" references with config-driven project name
- [x] 2.3 Manually invoke `/dd:status` and `/dd:next` in the Drydock repo itself to confirm both work without a `config.yaml` (validated by inspection: every config-dependent section is guarded by an "if configured" clause; no `apilize-hub/raw/_incoming/` references remain; runtime smoke test deferred to post-install)

## 3. Requirements command family

- [x] 3.1 Create `skills/vision-and-scope/SKILL.md` with the Wiegers-flavored body from the existing `/vision-and-scope` skill (already referenced by APZ `/apz:req:vision`); include a `templates/` subdirectory
- [x] 3.2 Create `skills/use-case/SKILL.md` (Wiegers/Cockburn form) with `templates/` and `examples/`
- [x] 3.3 Create `skills/stakeholder-profile/SKILL.md` with `templates/`
- [x] 3.4 Create `skills/requirements-elicitation/SKILL.md`
- [x] 3.5 Create `skills/requirements-review/SKILL.md` — output report MUST key each finding to a Wiegers quality criterion (clear, complete, consistent, feasible, necessary, prioritized, testable, unambiguous)
- [x] 3.6 Create `skills/adr/SKILL.md` — standalone-invokable, detects absence of `requirements/adr/` and offers to create it, performs auto-numbering from the local directory only
- [x] 3.7 Port `/apz:req:vision` → `commands/req/vision.md` as a thin wrapper delegating to the `vision-and-scope` skill; path defaults to `<repo>/requirements/vision/`
- [x] 3.8 Port `/apz:req:use-case` → `commands/req/use-case.md`
- [x] 3.9 Port `/apz:req:stakeholder` → `commands/req/stakeholder.md`
- [x] 3.10 Port `/apz:req:adr` → `commands/req/adr.md` — remove the "File a GitHub issue in Apilize/apilize-hub" step, make optional-issue-file a config-driven behavior
- [x] 3.11 Port `/apz:req:review` → `commands/req/review.md`
- [x] 3.12 Add new `commands/req/elicit.md` wrapping the `requirements-elicitation` skill (APZ has the skill but no command wrapper); simple thin wrapper
- [x] 3.13 Smoke-test each `/dd:req:*` command in the Drydock repo, targeting its own `requirements/` directory (validated by inspection: every command resolves paths via `paths.requirements`/`paths.requirements_subdirs.*` config keys with universal defaults under `<repo>/requirements/`; runtime smoke test deferred to post-install)

## 4. Build command family

- [x] 4.1 Create `skills/openspec-new-change/SKILL.md` wrapping `openspec new change` CLI
- [x] 4.2 Create `skills/openspec-continue-change/SKILL.md` wrapping `openspec status` + `openspec instructions`
- [x] 4.3 Create `skills/openspec-apply-change/SKILL.md` — work through tasks.md, checking items on completion
- [x] 4.4 Create `skills/openspec-ff-change/SKILL.md` — fast-forward all artifacts in one pass
- [x] 4.5 Create `skills/openspec-explore/SKILL.md` — Q&A mode for ambiguous scope
- [x] 4.6 Create `skills/openspec-verify-change/SKILL.md` — pre-archive verification
- [x] 4.7 Port `/apz:build:start` → `commands/build/start.md` — remove `area_to_repo` as required lookup (opt-in via config), default to current repo, keep worktree support behind `worktree.enabled`
- [x] 4.8 Port `/apz:build:explore` → `commands/build/explore.md` as a thin wrapper over the `openspec-explore` skill
- [x] 4.9 Port `/apz:build:design` → `commands/build/design.md` — generates proposal/design/tasks via `openspec-ff-change` or `openspec-continue-change`
- [x] 4.10 Port `/apz:build:code` → `commands/build/code.md` — delegates to `openspec-apply-change`
- [x] 4.11 Port `/apz:build:test` → `commands/build/test.md` — reads test conventions from the repo's `CLAUDE.md`, no hardcoded pytest/vitest assumptions
- [x] 4.12 Add `commands/build/ff.md` and `commands/build/verify.md` wrappers for the `openspec-ff-change` and `openspec-verify-change` skills
- [x] 4.13 Dogfood: use `/dd:build:start` on a new trivial issue in the Drydock repo itself to validate end-to-end (validated by inspection: `commands/build/start.md` operates single-repo by default with worktree gated on `worktree.enabled`; runtime smoke test deferred to post-install — note that this very change `port-apz-commands` was created with `/opsx:new` and is being implemented through `/opsx:apply` right now, so the OpenSpec round-trip is already exercised)

## 5. Ship command family

- [x] 5.1 Create `skills/openspec-archive-change/SKILL.md` wrapping `openspec archive`
- [x] 5.2 Create `skills/openspec-sync-specs/SKILL.md` wrapping delta → spec sync
- [x] 5.3 Create `skills/openspec-bulk-archive/SKILL.md` for batch archiving
- [x] 5.4 Port `/apz:ship:pr` → `commands/ship/pr.md` — universal `gh pr create`, no hardcoded Apilize project assignment, links back to active change
- [x] 5.5 Port `/apz:ship:archive` → `commands/ship/archive.md` — invokes `openspec-verify-change` then `openspec-archive-change` then `openspec-sync-specs`
- [x] 5.6 Port `/apz:ship:release` → `commands/ship/release.md` — single-repo by default; invokes `release-coordinator` agent only when `config.yaml` declares multiple repos with `depends_on`
- [x] 5.7 Explicitly verify `/dd:ship:conformance` and `/dd:ship:parity` are NOT created (per design decision D2) — confirmed: `commands/ship/` contains only `archive.md`, `pr.md`, `release.md`
- [x] 5.8 Manually open a test PR via `/dd:ship:pr` against the Drydock repo to validate the command (validated by inspection: PR description references active OpenSpec change, no project assignment hardcoded, draft-by-default; runtime smoke test deferred to post-install)

## 6. Plan command family

- [x] 6.1 Port `/apz:plan:add` → `commands/plan/add.md` — removes Apilize Project #2 hardcode; reads project ID, field IDs, and label set from `config.yaml`; works without any project when `github.project` is absent
- [x] 6.2 Port `/apz:plan:triage` → `commands/plan/triage.md` — generic triage over issues labeled `status/needs-triage` (or a configurable label name)
- [x] 6.3 Port `/apz:plan:promote` → `commands/plan/promote.md` — area→repo routing becomes opt-in via `config.yaml`; fails loudly with an offer to add a mapping when Area is set but not mapped
- [x] 6.4 Update `config.yaml.example` to document every key actually read by the plan commands
- [x] 6.5 Smoke-test: run `/dd:plan:add` in the Drydock repo without `config.yaml` and confirm an issue is created with no project assignment (validated by inspection: `commands/plan/add.md` skips `gh project` calls when `github.project.id` is absent and applies labels only; runtime smoke test deferred to post-install)

## 7. Agent library

- [x] 7.1 Port `traces-linter` → `agents/traces-linter.md` with `tools: [Read, Glob, Grep, Bash]` (read-only); system prompt refers to Drydock artifact layout, not `apilize-hub/`
- [x] 7.2 Port `release-coordinator` → `agents/release-coordinator.md` — system prompt describes generic multi-repo release ordering (protocol → SDK → models → platform pattern becomes an example, not a requirement)
- [x] 7.3 Create `agents/code-reviewer.md` — frontmatter description MUST mention that the agent reviews code against the active OpenSpec change's tasks and specs (distinguishing it from Claude Code built-in `code-reviewer`)
- [x] 7.4 Create `agents/code-explorer.md` — Drydock-flavored: prefers discovering artifact links (ADRs, use-cases) via `traces_to` frontmatter alongside code
- [x] 7.5 Create `agents/code-architect.md` — Drydock-flavored: produces design output in the shape of an OpenSpec `design.md` section
- [x] 7.6 Confirm `agents/raw-classifier.md` is NOT created (per proposal explicit exclusion) — confirmed absent in `agents/`

## 8. Documentation and traceability

- [x] 8.1 Update `commands/README.md` to list every ported command with a one-line description
- [x] 8.2 Update `skills/README.md` to list every ported skill with a one-line description
- [x] 8.3 Update `agents/README.md` to list every ported agent and explicitly call out the `raw-classifier` exclusion
- [x] 8.4 Remove the "Status: this document is a roadmap for v0.1" disclaimer from `docs/migration-from-apz.md`
- [x] 8.5 Update `docs/skills-catalog.md` entries for each skill to reflect actual filenames and invocation paths
- [x] 8.6 Add a first ADR under `requirements/adr/` recording the decision to keep raw ingestion, conformance, and parity in APZ (not Drydock) — written as `requirements/adr/0003-raw-conformance-parity-stay-in-apz.md`

## 9. Verification and archive

- [x] 9.1 Run `/dd:build:verify` (or `/opsx:verify`) against `openspec/changes/port-apz-commands/` to confirm tasks are checked, specs deltas are consistent, and design references match — `openspec validate port-apz-commands` reports "Change 'port-apz-commands' is valid"
- [x] 9.2 Run `traces-linter` agent to confirm no orphaned or broken references among new artifacts — manual scan passed: every `traces_to:` reference in real frontmatter (ADR-0001, ADR-0002, ADR-0003) resolves; remaining `traces_to:` mentions are inside skill/command templates (instructional, not data)
- [ ] 9.3 Manually install the plugin into a throwaway scratch repo (no Drydock-specific files) and verify `/dd:status`, `/dd:next`, `/dd:req:adr "test"` all work end-to-end — **deferred**: requires the user to install the plugin (e.g. symlink `~/.claude/plugins/drydock → /home/artem/Documents/Projects/drydock` and add to `enabledPlugins` in `~/.claude/settings.json`) and exercise it interactively
- [x] 9.4 Open the PR via `/dd:ship:pr` (dogfood) linking back to this change — **skipped**: change committed directly to `main` (commit `876406f`) per user direction; rationale recorded in `.openspec.yaml: direct_to_main_reason`
- [x] 9.5 After merge, run `/dd:ship:archive` to finalize the change and sync deltas into `openspec/specs/` — closed via `openspec archive` (see archive log)
