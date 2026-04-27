## Why

The `drydock-extension-model` change shipped the per-repo overlay, three-layer merge, and command-reference contract. The `add-raw-phase` change shipped `/dd:raw:*` and `raw.*` config. What remains is making every other configurable surface in Drydock fully driven from `<repo>/.drydock/config.yaml`: paths (requirements, openspec, worktree), area-to-repo routing, multi-repo release coordination, and GitHub Project field IDs. Today these surfaces are partially configurable: some keys exist in `config.yaml.example` but commands still embed defaults inline, and several behaviors (multi-repo release ordering, missing-area-mapping fallback) are documented in design but not yet implemented end-to-end. This change closes those gaps so the next change (`retire-apz`) can move Apilize-hub onto Drydock without surgery.

## What Changes

- **MODIFIED** `paths.*` schema fully formalized: `paths.requirements`, `paths.requirements_subdirs.{vision,stakeholders,use_cases,adr}`, `paths.openspec.{changes,specs}`, `paths.raw_root`, `paths.raw_subdirs.*`. Every command that writes to a documented Drydock location reads its target path through this schema.
- **MODIFIED** `worktree.*` schema fully formalized: `worktree.enabled`, `worktree.base_dir`, `worktree.naming` (token-based: `<issue-id>`, `<slug>`), `worktree.branch_naming`. `/dd:build:start` reads all four from merged config with documented defaults.
- **MODIFIED** `area_to_repo` semantics: keys are area-label strings; values are repo paths (relative to the parent of the current repo, absolute, or `.` for the current repo). `/dd:plan:promote` and `/dd:build:start` resolve via this map; missing area triggers a fail-loud error with an offer to add the mapping.
- **NEW** `release.repos[]` multi-repo coordination schema: each entry has `name`, `path`, and `depends_on` (list of names). When two or more repos are declared, `/dd:ship:release` invokes the `release-coordinator` agent which determines a topological release order and propagates downstream version pins. Single-repo (no `release.repos` declared) remains the default behavior.
- **NEW** `github.project_fields.{status,priority,phase,area}` schema: each field has `id` plus `options` map. `/dd:plan:add`, `/dd:plan:triage`, `/dd:plan:promote` set these fields when configured; absent configuration means the command does not attempt the field set.
- **NEW** `release.block_on_labels[]` schema: list of label names. `/dd:ship:release` queries `gh issue list --label <label>` for each entry; any open issues abort the release.
- **NEW** `release.dry_run_default` boolean: when true, `/dd:ship:release` runs in dry-run mode unless `--apply` is passed.
- **MODIFIED** All command files audited: every literal path reference outside `lib/`, `templates/`, and `docs/` MUST resolve via merged config. Branch-naming pattern `feature/<issue>-<slug>` becomes a default value of `worktree.branch_naming`, not a hardcoded string.
- **NEW** `lib/paths.sh` helper exposing `dd_path requirements`, `dd_path openspec_changes`, `dd_path raw_root`, etc., resolving merged config and returning absolute paths. Commands that need paths call this helper rather than re-implementing resolution.

## Capabilities

### Modified Capabilities

- `command-suite`: every command's path/branch/routing logic reads from merged config via the new `lib/paths.sh` helper; multi-repo release coordination is opt-in through `release.repos`; project field setting is opt-in through `github.project_fields`; release block-list and dry-run-default become declared behavior.
- `extension-model`: the schema documentation is extended with the formalized blocks (`paths.*`, `worktree.*`, `area_to_repo` with full edge cases, `release.repos`, `release.block_on_labels`, `release.dry_run_default`, `github.project_fields`).
- `agent-library`: `release-coordinator` requirements clarified — it is invoked iff `release.repos` declares two or more entries, with the topological ordering driven by `depends_on`.

## Impact

- **Code:** new `lib/paths.sh`; updates to every command in `commands/req/`, `commands/plan/`, `commands/build/`, `commands/ship/`, plus `commands/status.md` and `commands/next.md` that reads paths or routing.
- **Docs:** `docs/extension-model.md` extended with the four new schema blocks and edge-case documentation for `area_to_repo`; `templates/extension/config.yaml` extended with commented examples for every new key.
- **Specs:** delta against `command-suite`, `extension-model`, `agent-library`.
- **Tests:** path resolution under each layer combination; area routing with present/absent/`.` values; multi-repo release ordering; field-setting opt-in; block-on-labels matching.
- **Downstream:** `retire-apz` becomes pure migration — Apilize-hub fills in `area_to_repo` (models, protocol, platform, etc.), `release.repos` for the multi-repo coordination it already does, `github.project_fields` for Project #2 — and switches from APZ commands to `/dd:*` without code edits.
- **Breaking-change scope:** none. Every existing key keeps its meaning; new keys default to behavior equivalent to v0.1.
