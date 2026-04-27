# command-suite Specification

## Purpose
TBD - created by archiving change port-apz-commands. Update Purpose after archive.
## Requirements
### Requirement: Command namespace and layout

The Drydock plugin SHALL expose all slash commands under the `/dd:` namespace, organized into phase subdirectories under `commands/`: `req/` for requirements, `build/` for the build loop, `ship/` for the release pipeline, `plan/` for backlog planning, plus two top-level commands (`status`, `next`). Command files MUST be Markdown with YAML frontmatter containing at minimum `description` and `allowed-tools`.

#### Scenario: Phase-grouped commands discover correctly
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** `/dd:req:adr`, `/dd:build:start`, `/dd:ship:pr`, `/dd:plan:triage`, `/dd:status`, and `/dd:next` MUST all be invocable

#### Scenario: Top-level commands live at commands/ root
- **WHEN** the user invokes `/dd:status` or `/dd:next`
- **THEN** the corresponding command file MUST be at `commands/status.md` or `commands/next.md` respectively, not inside a phase subdirectory

### Requirement: Status command reports universal state

The `/dd:status` command SHALL report, in a concise section-based format under 30 lines, the following when invoked: current working directory; current git branch; count of uncommitted changes; whether the checkout is a worktree; the active OpenSpec change (if any) with its artifact progress; the linked issue (if the branch name matches `feature/<N>-*`); and open PRs authored by the user in the current repo. The command MUST NOT assume any specific GitHub organization, project board, or raw-inbox directory structure.

#### Scenario: Runs in an arbitrary git repo
- **WHEN** `/dd:status` is invoked inside a git repository with no Drydock-specific configuration
- **THEN** the command MUST produce a status report using only `git`, `gh`, and local filesystem checks, with no references to Apilize paths or project IDs

#### Scenario: Reports active OpenSpec change
- **WHEN** `openspec/changes/<slug>/` exists with proposal, design, or tasks artifacts and status is not `done`
- **THEN** `/dd:status` MUST list the change slug and the count of completed vs. total artifacts

### Requirement: Next command suggests exactly one action

The `/dd:next` command SHALL analyze current workflow state and propose exactly one next step, with optional ranked alternatives. The decision logic MUST traverse: active OpenSpec change with unfinished work → branch ahead of main without a PR → untriaged GitHub issues → clean main (suggest picking up an issue). The command MUST base every suggestion on observed state (filesystem, git, `gh`) and never fabricate.

#### Scenario: Unfinished tasks in active change
- **WHEN** `openspec/changes/<slug>/tasks.md` exists with unchecked items and the change status is not `done`
- **THEN** `/dd:next` MUST suggest `/dd:build:code` as the next step, naming the specific change slug

#### Scenario: Clean repo with no work in flight
- **WHEN** the working tree is clean on main, no active OpenSpec change exists, and no untriaged issues are found
- **THEN** `/dd:next` MUST report that the user is up to date and offer to pick an issue or start a new change

### Requirement: Requirements commands default to repo-local paths

The `/dd:req:*` commands (`vision`, `use-case`, `stakeholder`, `adr`, `review`, `elicit`) SHALL resolve default output locations against `<repo-root>/requirements/…` and MUST NOT reference `apilize-hub/` or any other fixed-project path. Paths MAY be overridden via `config.yaml` keys under a `paths.requirements.*` section.

#### Scenario: ADR auto-numbering scans local directory
- **WHEN** `/dd:req:adr` is invoked and `<repo-root>/requirements/adr/` contains ADR-001 through ADR-007
- **THEN** the new ADR MUST be numbered ADR-008, regardless of ADR numbers that may exist in other repositories

#### Scenario: Vision and Scope document placement
- **WHEN** `/dd:req:vision` is invoked with no configuration override
- **THEN** the generated document MUST be written under `<repo-root>/requirements/vision/`

### Requirement: Build start command operates on the current repo

The `/dd:build:start` command SHALL operate on the repository of the current working directory. Multi-repo routing via `area_to_repo` mapping MUST be opt-in: when `config.yaml` declares an `area_to_repo` table and the issue's Area field matches, the command MAY `cd` into the mapped repository; otherwise the current repo is used. The command MUST create a branch named per `config.yaml` `worktree.branch_naming` (default `feature/<issue>-<slug>`) and MAY create a git worktree when `config.yaml` `worktree.enabled` is true.

#### Scenario: Single-repo workflow without config
- **WHEN** `/dd:build:start 42` is invoked in a repo with no `config.yaml`
- **THEN** a branch named `feature/42-<slug>` MUST be created in the current repo and no worktree MUST be created

#### Scenario: Multi-repo routing when configured
- **WHEN** `/dd:build:start 42` is invoked, the issue has `Area: platform`, and `config.yaml` maps `area_to_repo.platform: ../other-platform-repo`
- **THEN** the command MUST change directory to the mapped repo before creating the branch

### Requirement: Ship commands exclude Apilize-specific gates

The `/dd:ship:*` command family SHALL include `pr`, `archive`, and `release`. It MUST NOT include `conformance` or `parity` commands, which are Apilize-Protocol-specific and remain in APZ. The `release` command MUST support single-repo operation by default; multi-repo coordination (via `release-coordinator` agent) is opt-in through configuration.

#### Scenario: Release command works without multi-repo config
- **WHEN** `/dd:ship:release` is invoked in a repo with no multi-repo declaration in `config.yaml`
- **THEN** the command MUST operate on only the current repo, bumping version, generating changelog, and tagging — without invoking the `release-coordinator` agent

#### Scenario: Conformance and parity are absent
- **WHEN** the user lists available commands after Drydock is installed
- **THEN** `/dd:ship:conformance` and `/dd:ship:parity` MUST NOT be present

### Requirement: Plan commands configure integrations via config.yaml

The `/dd:plan:*` commands (`add`, `triage`, `promote`) SHALL read GitHub Project ID, project field IDs, issue templates, label names, and area→repo mapping from `config.yaml`. No Apilize-specific default values (project number 2, specific field IDs, repo names) MAY appear in the command files. When `config.yaml` does not declare a GitHub Project, plan commands MUST still operate at the issue level without a project board.

#### Scenario: Plan add works without a GitHub Project configured
- **WHEN** `/dd:plan:add "Fix login bug"` is invoked in a repo whose `config.yaml` declares no `github.project`
- **THEN** a GitHub issue MUST be created with default labels and no project assignment, and the command MUST succeed

#### Scenario: Plan promote fails loudly on missing area mapping
- **WHEN** `/dd:plan:promote 42` is invoked, the issue has `Area: platform`, and `config.yaml` has no entry for `area_to_repo.platform`
- **THEN** the command MUST report the missing mapping, refuse to promote, and offer to add the mapping

### Requirement: No backward-compatibility aliases for APZ names

Drydock command files MUST NOT define aliases from `/apz:*` names to `/dd:*` names. The migration path is documented in `docs/migration-from-apz.md` and requires users to update their invocations. This aligns with the "Do not" rule in `CLAUDE.md`.

#### Scenario: Legacy APZ name does not resolve in Drydock
- **WHEN** a user invokes `/apz:req:adr` with only Drydock installed
- **THEN** the command MUST NOT resolve; only `/dd:req:adr` works

### Requirement: Configuration loaded via merged extension-model loader

All Drydock commands that read configuration SHALL do so via the merged config loader defined by the `extension-model` capability (see `specs/extension-model/spec.md`). References to `config.yaml` in this spec resolve to the materialized merged result of plugin-root, user-level, and per-repo layers. Commands MUST NOT read directly from `${CLAUDE_PLUGIN_ROOT}/config.yaml` after this change.

#### Scenario: Per-repo override takes effect
- **WHEN** plugin-root `config.yaml` declares `worktree.enabled: false`, `<repo>/.drydock/config.yaml` declares `worktree.enabled: true`, and `/dd:build:start 42` is invoked
- **THEN** the command MUST create a worktree

#### Scenario: No config files anywhere
- **WHEN** none of the three config layers contain a `config.yaml` and `/dd:build:start 42` is invoked
- **THEN** the command MUST fall back to documented built-in defaults and succeed

#### Scenario: Direct plugin-root reads forbidden
- **WHEN** an inspector greps the `commands/` directory for direct references to `${CLAUDE_PLUGIN_ROOT}/config.yaml`
- **THEN** no matches MUST be found outside `lib/config.sh` itself

### Requirement: Ship pr command invokes pre-pr lifecycle hook

The `/dd:ship:pr` command SHALL invoke `<repo>/.drydock/hooks/pre-pr.sh` (if present and executable) before opening the PR. The hook contract follows the protocol defined by the `extension-model` capability: JSON payload on stdin (with at least `event`, `repo_path`, `config_path`, `branch`, `commits`), non-zero exit aborts PR creation.

#### Scenario: Pre-pr hook aborts when failing
- **WHEN** `<repo>/.drydock/hooks/pre-pr.sh` exits non-zero and `/dd:ship:pr` is invoked
- **THEN** no PR MUST be created and the failure MUST be reported with the hook name and exit code

#### Scenario: Pre-pr hook absent
- **WHEN** no `pre-pr.sh` file exists and `/dd:ship:pr` is invoked
- **THEN** the PR MUST be created normally with no warning

#### Scenario: Pre-pr hook receives expected payload fields
- **WHEN** `<repo>/.drydock/hooks/pre-pr.sh` is invoked from `/dd:ship:pr` on branch `feature/42-dark-mode` ahead of `main` by 3 commits
- **THEN** the hook's JSON stdin payload MUST contain `event: "pre-pr"`, `repo_path`, `config_path`, `branch: "feature/42-dark-mode"`, and `commits` listing the 3 SHAs

### Requirement: Ship release command invokes pre-release hook and gate command-references

The `/dd:ship:release` command SHALL execute the following sequence in order: (1) invoke `<repo>/.drydock/hooks/pre-release.sh` if present (abort on non-zero); (2) execute each item in `release.gates` (a list of slash-command references) in declared order via the command-reference contract; (3) on all gates passing, perform the release work (version bump, changelog, tag, optional multi-repo coordination). Any non-zero gate MUST abort the release with no version bump and no tag.

#### Scenario: Pre-release hook gates the entire release
- **WHEN** `<repo>/.drydock/hooks/pre-release.sh` exits non-zero and `/dd:ship:release` is invoked
- **THEN** no gates MUST run, no version bump MUST occur, and no tag MUST be created

#### Scenario: Gates run in declared order and abort on failure
- **WHEN** `release.gates: [/dd:build:test, /conformance, /parity]` is configured and `/dd:build:test` fails
- **THEN** `/conformance` and `/parity` MUST NOT run, and no version bump or tag MUST occur

#### Scenario: No gates declared
- **WHEN** `release.gates` is unset or an empty list and `/dd:ship:release` is invoked
- **THEN** the command MUST proceed directly to version bump and tag (after the pre-release hook, if any)

#### Scenario: Project-local gate reference
- **WHEN** `release.gates: [/conformance]` is configured, `<repo>/.claude/commands/conformance.md` exists, and `/dd:ship:release` is invoked
- **THEN** `/conformance` MUST execute via Claude Code slash dispatch as a gate

#### Scenario: Unresolved gate reference aborts release
- **WHEN** `release.gates: [/typo-conformance]` is configured (no command at that name exists) and `/dd:ship:release` is invoked
- **THEN** the release MUST abort with an error naming `/typo-conformance` as unresolved

### Requirement: Ship archive command invokes post-archive hook

The `/dd:ship:archive` command SHALL invoke `<repo>/.drydock/hooks/post-archive.sh` (if present and executable) after a successful archive (delta sync complete, change archived). A non-zero exit from the hook MUST be reported as a warning but MUST NOT roll back the archive — the archived state MUST remain committed.

#### Scenario: Post-archive hook failure does not roll back
- **WHEN** `<repo>/.drydock/hooks/post-archive.sh` exits non-zero after `/dd:ship:archive` completes its sync and archive
- **THEN** the warning MUST be visible to the user, the archive MUST remain committed, and the change MUST remain archived

### Requirement: /dd:raw:* command namespace

Drydock SHALL expose the following commands under the `/dd:raw:` namespace, each as a Markdown file under `commands/raw/`: `capture.md`, `process.md`, `ingest-gmail.md`, `ingest-calendar.md`, `ingest-drive.md`, `ingest-notion.md`, `ingest-linear.md`, `ingest-github.md`, `transcribe.md`. Each command MUST follow the standard frontmatter convention (description, allowed-tools).

#### Scenario: All raw commands discover correctly
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** `/dd:raw:capture`, `/dd:raw:process`, `/dd:raw:ingest-gmail`, `/dd:raw:ingest-calendar`, `/dd:raw:ingest-drive`, `/dd:raw:ingest-notion`, `/dd:raw:ingest-linear`, `/dd:raw:ingest-github`, and `/dd:raw:transcribe` MUST all be invocable

#### Scenario: Command files contain no organization-specific content
- **WHEN** an inspector greps `commands/raw/` for any client/product name (e.g. `apilize`, `wertxpert`, `intreal`)
- **THEN** zero matches MUST be found

### Requirement: Status command summarizes raw inbox

The `/dd:status` command SHALL include a one-line "Raw inbox" summary reporting the count of files in `<repo>/<paths.raw_root>/_incoming/` and (if available) the timestamp of the most recent `/dd:raw:process` invocation.

#### Scenario: Inbox count reported when present
- **WHEN** `<repo>/raw/_incoming/` contains 12 files and `/dd:status` is invoked
- **THEN** the output MUST include a line like `Raw inbox: 12 in _incoming` (or equivalent format under 80 characters)

#### Scenario: No raw root configured
- **WHEN** the repo has no `paths.raw_root` configured AND no default `raw/` directory exists
- **THEN** `/dd:status` MUST omit the Raw inbox line entirely (rather than reporting `0 in _incoming`)

### Requirement: Next command suggests process when inbox is non-empty

The `/dd:next` command SHALL include in its decision logic: if `<repo>/<paths.raw_root>/_incoming/` contains one or more files, suggest `/dd:raw:process` as the next action (with priority above starting new build work). The suggestion MUST name the file count.

#### Scenario: Non-empty inbox prioritized
- **WHEN** `_incoming/` contains 3 files, no active OpenSpec change exists, and `/dd:next` is invoked
- **THEN** the suggestion MUST be `/dd:raw:process` and MUST include the count `3`

#### Scenario: Empty inbox does not trigger raw suggestion
- **WHEN** `_incoming/` is empty
- **THEN** `/dd:next` MUST NOT mention `/dd:raw:process`; the existing decision logic for changes/PRs/issues applies

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

#### Scenario: Relative path resolved against parent of current repo (sibling-name pattern)
- **WHEN** the current repo is at `/home/me/work/hub` and `area_to_repo: {frontend: frontend}` is configured and `/dd:plan:promote 42` runs on an issue with `Area: frontend`
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

