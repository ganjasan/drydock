## Context

After `drydock-extension-model` and `add-raw-phase` apply, the remaining configuration gaps are the long-tail keys: paths, worktree, area routing, multi-repo release coordination, and GitHub Project field IDs. Each is partially supported today — referenced in `config.yaml.example`, mentioned in command files — but the actual command logic falls back to inline defaults rather than reading the merged config consistently.

The constraint set:

- **Backward-compatible defaults.** Every command's default behavior with an empty config must match v0.1 behavior. Apilize-hub will move to `<repo>/.drydock/config.yaml` in `retire-apz`; no third party is on the v0.1 layout.
- **Single helper for path resolution.** Re-implementing `paths.requirements/vision/...` in every requirement command is the source of drift. One helper, `lib/paths.sh`, owns this.
- **Opt-in advanced behaviors.** Multi-repo coordination, project-field setting, block-on-labels, dry-run-default are all opt-in: declared = active, undeclared = quiet.
- **Fail loud on missing area mappings.** `/dd:plan:promote` for an issue with `Area: foo` and no `area_to_repo.foo` declared must abort with a clear "add this mapping" prompt — silent fallback to the current repo would mis-route work.

## Goals / Non-Goals

**Goals:**

- A `lib/paths.sh` helper that resolves every documented Drydock path against merged config, with documented defaults.
- A formalized `worktree.*` schema with token-based naming (`<issue-id>`, `<slug>`) and consistent application across `/dd:build:start`.
- `area_to_repo` with full edge-case semantics: relative path, absolute path, `.` for current repo, missing key behavior, missing config behavior.
- `release.repos[]` multi-repo coordination with `depends_on`-driven topological ordering.
- `github.project_fields` opt-in field setting in plan commands.
- `release.block_on_labels` and `release.dry_run_default` keys.
- Audit of every command file: zero hardcoded path/branch/routing literals outside the helpers.

**Non-Goals:**

- Changing any command-name surface. All `/dd:*` commands keep their names and outward semantics.
- Adding new commands. This is config plumbing.
- Building a `release.gates`-like mechanism for non-release commands. Gates remain a release-only concept.
- Supporting non-GitHub trackers (Linear, Jira). That is v0.3.

## Decisions

### D1. `lib/paths.sh` is the single resolver

API surface (shell functions):

- `dd_path requirements` → absolute path under `<repo>/<paths.requirements>`.
- `dd_path requirements_subdir <vision|stakeholders|use_cases|adr>` → absolute path including the merged subdir name.
- `dd_path openspec_changes` → `<repo>/<paths.openspec.changes>`.
- `dd_path openspec_specs` → `<repo>/<paths.openspec.specs>`.
- `dd_path raw_root` → `<repo>/<paths.raw_root>`.
- `dd_path raw_subdir <name>` → `<repo>/<paths.raw_root>/<paths.raw_subdirs.<name>>`.
- `dd_path worktree_base` → resolved `worktree.base_dir`.
- `dd_branch_name <issue-id> <slug>` → resolved `worktree.branch_naming` with tokens substituted.
- `dd_worktree_dir <issue-id> <slug>` → resolved `worktree.naming` with tokens substituted, joined to `worktree_base`.

Every command that needs a path calls the helper; commands never read `paths.*` directly. This is the same pattern as `lib/config.sh` for general key access — but specialized so that path-shaped values get one consistent treatment (joined against `<repo>` root, normalized).

### D2. `area_to_repo` resolution: explicit fail on miss, multiple value forms accepted

Resolution order for `/dd:plan:promote 42` with issue `Area: platform`:

1. If `area_to_repo` is unset entirely → operate on the current repo.
2. If `area_to_repo.platform` is unset but `area_to_repo` is non-empty → abort with "Area `platform` has no mapping in `area_to_repo`. Add a mapping or set `Area:` to a known value."
3. If the value is `.` → operate on the current repo.
4. If the value is absolute → operate on that path.
5. If the value is relative → resolved against `<current-repo-parent-dir>` (so `../my-frontend` works for sibling-repo layouts).

This produces the right behavior for: solo repo (don't declare `area_to_repo`); single-area redirection (`area_to_repo.docs: .`); sibling-repo team (`area_to_repo.frontend: ../frontend`); absolute-path edge case (`area_to_repo.shared: /opt/shared-repo`).

### D3. `release.repos[]` topological ordering, single-repo default

Single-repo case (no `release.repos` declared, or one entry only): `/dd:ship:release` operates in the current repo without invoking `release-coordinator`. This is the universal default.

Multi-repo case (≥2 entries): the `release-coordinator` agent is invoked with the full `release.repos` list and the originating change. The agent computes a topological order from `depends_on` (Kahn's algorithm), invokes per-repo release flow in order, and propagates downstream version pins (e.g. when the protocol repo bumps to v1.5.0, the platform repo's manifest updates its `protocol` dependency to `^1.5.0`).

If `depends_on` declares a cycle, the agent aborts before any release work begins.

### D4. `github.project_fields` opt-in field setting

Each field block (`status`, `priority`, `phase`, `area`) has `id` and `options` (map of canonical name → field option ID). Plan commands check field presence:

- If `github.project_fields.status` is configured → set Status to the appropriate option after creating or moving an issue.
- If unset → skip the field set; the issue lands in the project-board's default state (or no board if `github.project` is also unset).

This handles the spectrum: solo repo with no project board → all skipped; team repo with a project but no custom fields → board assignment only; team repo with full field config → full automation.

### D5. `release.block_on_labels` and `release.dry_run_default` are pre-release safety

`block_on_labels`: the release aborts if any open issue carries any of the listed labels. Implementation: `gh issue list --label "<each-label>" --state open --json number`; if any returns non-empty, the release aborts citing the first match.

`dry_run_default`: when true, `/dd:ship:release` defaults to dry-run unless explicitly invoked with `--apply`. This is a guard against accidental release in repos where the user wants explicit confirmation. Default is `false` so single-developer flow is uninterrupted.

Both are pre-`release.gates` checks, before any pre-release hook.

### D6. Worktree naming via tokens, no string interpolation in command files

Default `worktree.branch_naming: "feature/<issue-id>-<slug>"`. The helper `dd_branch_name 42 "dark-mode"` returns `"feature/42-dark-mode"`. Tokens supported: `<issue-id>`, `<slug>`. Future tokens (e.g. `<phase>`, `<area>`) require a documented schema bump; commands MUST NOT inline `printf`-style string composition.

This guarantees a single source of truth for naming. If a project wants `"work/<area>/<issue-id>-<slug>"`, they add `<area>` token support to `dd_branch_name` in one place.

### D7. Audit assertion: zero path literals outside helpers

After this change applies, a grep across `commands/` for path-like strings (`requirements/`, `openspec/changes/`, `feature/`, `raw/_incoming/`) MUST yield zero matches outside markdown documentation blocks. The helpers are the only place these strings appear. The change includes a verification task that codifies this assertion.

## Risks / Trade-offs

- **Helpers add a layer between command files and behavior.** → Mitigation: helpers are tiny shell functions with one job. Commands call `dd_path requirements`, not "read merged config and resolve and join". The layer makes the contract enforceable.
- **Multi-repo release-coordinator becomes complex.** → Mitigation: single-repo default sidesteps it entirely; the agent is only invoked when explicitly declared. Cycle detection aborts before any side effect.
- **Field-setting silently skipping when config is absent could surprise users who think the project board is fully wired.** → Mitigation: `/dd:status` reports which project fields are configured vs not, so the user can see what's hooked up.
- **`area_to_repo` fail-loud might frustrate "I just want to keep going" cases.** → Mitigation: the error message includes a copy-pasteable diff to add the mapping. One-time annoyance with high accuracy beats silent mis-routing.
- **Helpers in shell can be slow if invoked many times per command.** → Mitigation: command files invoke each `dd_path` lookup at most once per path; merged-config materialization (already cached per command via `DRYDOCK_CONFIG_PATH`) means subsequent reads hit a tempfile.

## Migration Plan

This change is internal Drydock infrastructure. No external consumer is on the keys being formalized (Apilize-hub still uses APZ commands; it will switch to `/dd:*` in `retire-apz` after this change applies). Migration in this repo:

1. Land `lib/paths.sh` with full test coverage.
2. One-by-one update each command to read paths through the helper. Each command edit is its own commit.
3. Update `docs/extension-model.md` with the formalized schema; update `templates/extension/config.yaml` with new commented blocks.
4. Run the audit grep; fix any leakage.
5. Smoke-test in this repo: set `paths.requirements: docs/req`; verify `/dd:req:vision` writes under `docs/req/vision/`; revert.

Rollback: revert the change. The helpers are net-new; commands fall back to their inline literals.

## Open Questions

- **Should `paths.*` keys default to absolute or relative resolution?** — Decision: relative-to-repo-root by default; absolute paths in config are honored if they start with `/`. Documented in the schema.
- **Is `release.repos.path` resolved relative to the current repo or to the repo declaring it?** — Decision: relative to the repo declaring it (`<repo>/.drydock/config.yaml`'s parent), so a hub-style "this repo orchestrates" config makes sense. Worktree resolution follows the same rule.
- **Does this change need to ship with multi-repo release tests?** — Decision: yes, at fixture level. Real cross-repo integration is exercised in `retire-apz` against Apilize-hub's actual `release.repos`.
- **Should `github.project_fields` support custom fields beyond status/priority/phase/area?** — Decision: not in v0.2. The four cover Apilize-hub's actual usage; new fields require a schema bump and will be data-driven in v0.3 if usage demands it.
