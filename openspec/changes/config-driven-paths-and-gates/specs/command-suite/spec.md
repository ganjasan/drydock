## ADDED Requirements

### Requirement: All path-shaped values resolve via lib/paths.sh

Every Drydock command that needs a path under documented Drydock layouts (requirements, OpenSpec, raw inbox, worktrees) SHALL resolve it via the `lib/paths.sh` helper API: `dd_path requirements`, `dd_path requirements_subdir <name>`, `dd_path openspec_changes`, `dd_path openspec_specs`, `dd_path raw_root`, `dd_path raw_subdir <name>`, `dd_path worktree_base`, `dd_branch_name <issue> <slug>`, `dd_worktree_dir <issue> <slug>`. Command files MUST NOT contain path literals like `requirements/`, `openspec/changes/`, `feature/<issue>-`, or `raw/_incoming/` outside markdown documentation blocks.

#### Scenario: Helper used for ADR resolution
- **WHEN** `/dd:req:adr` runs in a repo with `paths.requirements: docs/req` and `paths.requirements_subdirs.adr: decisions`
- **THEN** the new ADR MUST be written under `<repo>/docs/req/decisions/`

#### Scenario: Helper used for OpenSpec change creation
- **WHEN** `/dd:build:start 42` runs in a repo with `paths.openspec.changes: spec/changes`
- **THEN** the new change directory MUST be created under `<repo>/spec/changes/<slug>/`

#### Scenario: Audit grep finds no leakage
- **WHEN** an inspector greps `commands/` for the strings `requirements/`, `openspec/changes/`, `feature/<`, `raw/_incoming/`, or `.worktrees/` (excluding markdown code blocks documenting examples)
- **THEN** zero functional matches MUST be found

### Requirement: Worktree naming uses token substitution

The `/dd:build:start` command SHALL produce branch names via `dd_branch_name <issue-id> <slug>` and worktree directory names via `dd_worktree_dir <issue-id> <slug>`. Both helpers read `worktree.branch_naming` and `worktree.naming` from merged config, with token substitution for `<issue-id>` and `<slug>`. Default templates: `worktree.branch_naming: "feature/<issue-id>-<slug>"`, `worktree.naming: "wt-<issue-id>"`.

#### Scenario: Default branch naming
- **WHEN** `/dd:build:start 42` runs in a repo with no `worktree.*` overrides and slug derived as `dark-mode`
- **THEN** the created branch MUST be named exactly `feature/42-dark-mode`

#### Scenario: Custom branch naming via config
- **WHEN** `worktree.branch_naming: "issue/<issue-id>/<slug>"` is configured and `/dd:build:start 42` runs with slug `dark-mode`
- **THEN** the created branch MUST be named `issue/42/dark-mode`

#### Scenario: Custom worktree directory naming
- **WHEN** `worktree.enabled: true` and `worktree.naming: "<issue-id>-<slug>"` are configured and `/dd:build:start 42` runs with slug `dark-mode`
- **THEN** the worktree directory MUST be `<worktree.base_dir>/42-dark-mode`

### Requirement: area_to_repo resolution edge cases

The `/dd:plan:promote` and `/dd:build:start` commands SHALL resolve the issue's `Area` field against `area_to_repo` per the documented edge-case rules: (1) `area_to_repo` unset entirely → current repo; (2) `area_to_repo` set but the issue's area not in the map → abort with fail-loud message offering to add the mapping; (3) value `.` → current repo; (4) absolute path (starts with `/`) → that path; (5) relative path → resolved against the parent directory of the current repo.

#### Scenario: No area_to_repo means current repo
- **WHEN** `area_to_repo` is not declared and `/dd:plan:promote 42` runs on an issue with `Area: anything`
- **THEN** the change MUST be created in the current repo

#### Scenario: Missing area mapping aborts
- **WHEN** `area_to_repo: {frontend: ../fe}` is configured and `/dd:plan:promote 42` runs on an issue with `Area: backend`
- **THEN** the command MUST abort with a message naming `backend` as the missing mapping and offering to add `area_to_repo.backend`

#### Scenario: Dot value means current repo
- **WHEN** `area_to_repo: {docs: .}` is configured and `/dd:plan:promote 42` runs on an issue with `Area: docs`
- **THEN** the change MUST be created in the current repo (no `cd` to elsewhere)

#### Scenario: Relative path resolved against parent of current repo
- **WHEN** the current repo is at `/home/me/work/hub` and `area_to_repo: {frontend: ../frontend}` is configured and `/dd:plan:promote 42` runs on an issue with `Area: frontend`
- **THEN** the command MUST cd into `/home/me/work/frontend` before creating the change

#### Scenario: Absolute path used verbatim
- **WHEN** `area_to_repo: {shared: /opt/shared-repo}` is configured and `/dd:plan:promote 42` runs on an issue with `Area: shared`
- **THEN** the command MUST cd into `/opt/shared-repo`

### Requirement: release.repos multi-repo coordination opt-in

The `/dd:ship:release` command SHALL operate in single-repo mode by default. When `release.repos` is declared with two or more entries, the command SHALL invoke the `release-coordinator` agent passing the full `release.repos` list. The agent MUST compute a topological order from `depends_on` and execute per-repo release flow in that order. If `depends_on` declares a cycle, the agent MUST abort before any release work in any repo.

#### Scenario: Single-repo default
- **WHEN** `/dd:ship:release` is invoked in a repo with no `release.repos` declared
- **THEN** the command MUST operate only on the current repo and MUST NOT invoke the `release-coordinator` agent

#### Scenario: Single-entry release.repos
- **WHEN** `release.repos: [{name: foo, path: ., depends_on: []}]` is declared (one entry)
- **THEN** the command MUST treat this as single-repo and MUST NOT invoke the agent

#### Scenario: Multi-repo with dependencies
- **WHEN** `release.repos` declares `[{name: protocol, path: ../protocol, depends_on: []}, {name: platform, path: ../platform, depends_on: [protocol]}]` and `/dd:ship:release` is invoked
- **THEN** the agent MUST execute `protocol` first, then `platform`, propagating any version pin from the first to the second

#### Scenario: Cycle aborts before side effects
- **WHEN** `release.repos` declares `[{name: a, depends_on: [b]}, {name: b, depends_on: [a]}]`
- **THEN** the agent MUST abort with a clear cycle-detected error; no version bumps or tags MUST be created in any repo

### Requirement: github.project_fields opt-in field setting

The `/dd:plan:add`, `/dd:plan:triage`, and `/dd:plan:promote` commands SHALL set a GitHub Project field iff that field is configured under `github.project_fields.<field>.id` and `github.project_fields.<field>.options`. When the field is not configured, the command MUST skip the field set without error.

#### Scenario: Status set when configured
- **WHEN** `github.project_fields.status: {id: PVTSSF_x, options: {backlog: x1, in_progress: x2}}` is configured and `/dd:plan:add` creates an issue
- **THEN** the issue's project Status field MUST be set to option `x1` (Backlog)

#### Scenario: Status skipped when unconfigured
- **WHEN** `github.project_fields` is empty and `/dd:plan:add` creates an issue
- **THEN** the command MUST succeed without attempting any field set; the issue lands at the project board's default state (or no board if `github.project` is unset)

### Requirement: release.block_on_labels and release.dry_run_default

The `/dd:ship:release` command SHALL run a pre-flight check before any other release work: if `release.block_on_labels` is non-empty, query `gh issue list --label <label> --state open` for each label; any non-empty result MUST abort the release citing the blocking labels and issue numbers. When `release.dry_run_default: true` is configured, the command SHALL run in dry-run mode (no version bump, no tag, no push) unless explicitly invoked with `--apply`.

#### Scenario: Block-on-labels aborts release
- **WHEN** `release.block_on_labels: [priority/P0]` is configured, an open issue #5 has label `priority/P0`, and `/dd:ship:release` is invoked
- **THEN** the release MUST abort, no version bump or tag MUST occur, and the message MUST cite `priority/P0` and issue #5

#### Scenario: Dry-run default applied
- **WHEN** `release.dry_run_default: true` is configured and `/dd:ship:release` is invoked without `--apply`
- **THEN** the command MUST simulate every step (gates, version bump, changelog, tag) but MUST NOT mutate any state (no version commit, no tag, no push)

#### Scenario: Apply flag overrides default
- **WHEN** `release.dry_run_default: true` is configured and `/dd:ship:release --apply` is invoked
- **THEN** the command MUST perform all steps including the mutating ones
