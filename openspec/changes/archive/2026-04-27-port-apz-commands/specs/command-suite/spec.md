## ADDED Requirements

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
