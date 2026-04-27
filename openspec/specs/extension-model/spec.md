# extension-model Specification

## Purpose

Defines how a project plugs its own specifics into Drydock without forking the plugin or maintaining a sibling plugin. Three repo-local mechanisms — `<repo>/.drydock/config.yaml` (declarative configuration), `<repo>/.drydock/hooks/<event>.sh` (imperative lifecycle scripts), and `<repo>/.claude/commands/<name>.md` (project-local slash commands referenced from config) — together carry every Apilize-, FASTSAAS-, or other-project specific value while the plugin code stays universal. Documented in `docs/extension-model.md` and ratified by ADR-0004.

## Requirements

### Requirement: Per-repo configuration overlay location

Drydock SHALL look for a per-repo configuration file at `<repo-root>/.drydock/config.yaml`. The directory `<repo-root>/.drydock/` SHALL also house lifecycle hooks under `<repo-root>/.drydock/hooks/`. The directory MAY be absent — when absent, all configuration falls back to lower-priority layers (user-level and plugin-root defaults). Drydock MUST NOT use any other per-repo configuration location.

#### Scenario: Per-repo config is loaded when present
- **WHEN** Drydock is invoked in a repo where `<repo>/.drydock/config.yaml` declares `paths.requirements: "docs/req"`
- **THEN** `/dd:req:vision` MUST resolve its output path under `<repo>/docs/req/vision/`

#### Scenario: Repo without overlay still works
- **WHEN** Drydock is invoked in a repo with no `.drydock/` directory and no other configuration
- **THEN** all commands MUST function using built-in defaults

#### Scenario: Alternate locations are not searched
- **WHEN** a repo contains `<repo>/drydock.yaml` or `<repo>/.drydock.yaml` but not `<repo>/.drydock/config.yaml`
- **THEN** Drydock MUST NOT load configuration from those alternate paths

### Requirement: Three-layer config merge order

Drydock SHALL merge configuration from three layers, with later layers overriding earlier ones at the leaf-key level: (1) plugin-root defaults at `${CLAUDE_PLUGIN_ROOT}/config.yaml`, (2) optional user-level config at `~/.drydock/config.yaml`, (3) per-repo config at `<repo-root>/.drydock/config.yaml`. Map values MUST merge key-by-key; list values MUST be replaced wholesale (the deepest-level list defined wins).

#### Scenario: Per-repo overrides user-level overrides plugin defaults
- **WHEN** plugin-root sets `worktree.enabled: false`, user-level sets `worktree.enabled: true`, and per-repo sets `worktree.enabled: false`
- **THEN** the effective value of `worktree.enabled` MUST be `false`

#### Scenario: Maps merge key-by-key
- **WHEN** plugin-root sets `area_to_repo: {a: x, b: y}` and per-repo sets `area_to_repo: {b: z, c: w}`
- **THEN** the effective `area_to_repo` MUST be `{a: x, b: z, c: w}`

#### Scenario: Lists are replaced wholesale
- **WHEN** plugin-root sets `release.gates: [/dd:build:test]` and per-repo sets `release.gates: [/conformance]`
- **THEN** the effective `release.gates` MUST be exactly `[/conformance]`

#### Scenario: User-level layer is optional
- **WHEN** `~/.drydock/config.yaml` does not exist
- **THEN** the merge MUST proceed using only the plugin-root and per-repo layers

### Requirement: Materialized merged config available to commands and hooks

Each Drydock command invocation SHALL materialize the merged configuration to a JSON tempfile and expose its path via an environment variable `DRYDOCK_CONFIG_PATH` for the duration of the command. Hook scripts invoked during the command MUST receive the same path in their JSON stdin payload under the key `config_path`. Tempfiles MUST be cleaned up on command completion regardless of exit status.

#### Scenario: Command and hook see the same merged config
- **WHEN** `/dd:ship:pr` runs with three populated config layers, and `<repo>/.drydock/hooks/pre-pr.sh` is invoked
- **THEN** the file at `$DRYDOCK_CONFIG_PATH` (in the command) and the file at `payload.config_path` (in the hook) MUST be identical

#### Scenario: Tempfile is removed even on hook abort
- **WHEN** `/dd:ship:pr` invokes `pre-pr.sh` which exits non-zero
- **THEN** the materialized config tempfile MUST be removed before the command returns

### Requirement: Lifecycle-hook discovery and skip semantics

Drydock SHALL look for project-local hooks at `<repo-root>/.drydock/hooks/<hook-name>.sh`. A hook fires when its corresponding lifecycle event occurs and its file is executable. Missing files MUST be silently skipped. Non-executable files MUST be skipped with a one-line warning to surface possible misconfiguration without aborting.

#### Scenario: Executable hook fires
- **WHEN** `<repo>/.drydock/hooks/pre-pr.sh` exists, is chmod +x, and `/dd:ship:pr` is invoked
- **THEN** the hook MUST be executed before PR creation

#### Scenario: Missing hook is silently skipped
- **WHEN** no `<repo>/.drydock/hooks/pre-pr.sh` file exists and `/dd:ship:pr` is invoked
- **THEN** the command MUST proceed without error or warning

#### Scenario: Non-executable hook produces a warning
- **WHEN** `<repo>/.drydock/hooks/pre-pr.sh` exists but is not chmod +x and `/dd:ship:pr` is invoked
- **THEN** the command MUST emit a warning naming the hook and proceed without invoking it

### Requirement: Initial set of lifecycle hook points

Drydock v0.2 SHALL define the following lifecycle hook points: `pre-pr` (before `/dd:ship:pr` opens the PR), `pre-release` (before `/dd:ship:release` runs gates and tags), `post-archive` (after `/dd:ship:archive` syncs deltas and completes), `post-capture` (after a `/dd:raw:capture` or `/dd:raw:ingest-*` command files an item — defined here at the protocol level even though the invokers ship in a later change), and `session-start` (Claude Code SessionStart event). These names MUST be stable across v0.x; new hook points MAY be added in subsequent versions; existing names MUST NOT be renamed or removed within v0.x.

#### Scenario: All five named hooks are recognized
- **WHEN** the user copies one of the five named scripts into `<repo>/.drydock/hooks/` with executable bit set
- **THEN** Drydock MUST invoke that script at the corresponding lifecycle event (or, for `post-capture`, MUST be wired up in the protocol such that subsequent changes can invoke it without further protocol work)

### Requirement: Hook stdin payload schema

Each hook script SHALL receive a JSON payload on standard input. The payload MUST include at least these keys: `event` (string, the hook name), `repo_path` (absolute path to the repo root), `config_path` (absolute path to the materialized merged config JSON for the current command), and event-specific fields documented in `docs/extension-model.md`. The payload schema for each hook MUST be stable within v0.x (additive changes only).

#### Scenario: Pre-pr payload includes branch and commit context
- **WHEN** `<repo>/.drydock/hooks/pre-pr.sh` is invoked from `/dd:ship:pr`
- **THEN** the JSON stdin payload MUST contain at least: `event: "pre-pr"`, `repo_path`, `config_path`, `branch` (current branch name), and `commits` (list of commit SHAs ahead of the base branch)

#### Scenario: Post-archive payload includes change slug
- **WHEN** `<repo>/.drydock/hooks/post-archive.sh` is invoked from `/dd:ship:archive`
- **THEN** the JSON stdin payload MUST contain at least: `event: "post-archive"`, `repo_path`, `config_path`, and `change_slug` (the archived change's directory name)

### Requirement: Hook exit-code semantics

The exit code of a hook script SHALL determine whether the operation aborts. For `pre-*` hooks: a non-zero exit MUST abort the originating Drydock operation and report the hook name and exit code; the operation MUST NOT proceed. For `post-*` hooks: a non-zero exit MUST be reported as a warning but the operation MUST NOT be rolled back. For `session-start`: a non-zero exit MUST be reported and the Claude Code session MUST continue normally.

#### Scenario: Pre-release hook failure aborts release
- **WHEN** `<repo>/.drydock/hooks/pre-release.sh` exits with code 2 and `/dd:ship:release` is invoked
- **THEN** the release MUST abort, no version bump or tag MUST be created, and the message MUST identify `pre-release` as the failing hook with code 2

#### Scenario: Post-archive hook failure does not roll back
- **WHEN** `<repo>/.drydock/hooks/post-archive.sh` exits non-zero after `/dd:ship:archive` completes its sync and archive
- **THEN** the warning MUST be reported but the archived state MUST remain committed and the change MUST remain archived

#### Scenario: Session-start hook failure does not abort the session
- **WHEN** `<repo>/.drydock/hooks/session-start.sh` exits non-zero on Claude Code SessionStart
- **THEN** the warning MUST be reported and the Claude Code session MUST continue without further interruption

### Requirement: Command-reference contract for config-driven invocation

Configuration values that accept slash-command references (e.g. `release.gates`) SHALL be invoked via Claude Code's native slash-command dispatch. Both built-in `/dd:*` commands and project-local commands at `<repo-root>/.claude/commands/<name>.md` MUST be addressable. Drydock MUST NOT implement its own command resolution. If a referenced command does not resolve, the invoking operation MUST abort with a "command not found" error naming the unresolved reference.

#### Scenario: Built-in command reference
- **WHEN** `release.gates: [/dd:build:test]` is configured and `/dd:ship:release` runs
- **THEN** `/dd:build:test` MUST execute as a gate before tagging

#### Scenario: Project-local command reference
- **WHEN** `release.gates: [/conformance]` is configured, `<repo>/.claude/commands/conformance.md` exists, and `/dd:ship:release` runs
- **THEN** `/conformance` MUST execute as a gate before tagging

#### Scenario: Unresolved command reference fails loudly
- **WHEN** `release.gates: [/nonexistent]` is configured and `/dd:ship:release` runs
- **THEN** the release MUST abort, no tag MUST be created, and the error MUST name `/nonexistent` as the unresolved reference

### Requirement: Documentation at docs/extension-model.md

Drydock SHALL ship `docs/extension-model.md` as the canonical user-facing reference for the extension model. The document MUST contain: (1) the configuration schema covering at minimum `paths.*`, `github.*`, `area_to_repo`, `release.gates`, `release.repos`, `worktree.*`, and a placeholder section for `raw.*` documenting that it is populated by the `add-raw-phase` change; (2) the three-layer merge order with a worked example; (3) a lifecycle-hook table listing all initial five hook points with trigger, JSON-payload schema, and exit-code semantics; (4) the command-reference contract; (5) at least one end-to-end example showing a real `<repo>/.drydock/config.yaml` and a hook script.

#### Scenario: Doc covers schema, merge, hooks, references, and an example
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST contain all five elements above (config schema, merge order, hook table, command-reference contract, end-to-end example)

#### Scenario: Doc references the templates skeleton
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST reference `templates/extension/` as the starting skeleton for new repos

### Requirement: Templates skeleton at templates/extension/

Drydock SHALL ship a `templates/extension/` directory containing a `config.yaml` template (with all top-level keys present and commented) and example scripts under `templates/extension/hooks/` (one `*.sh.example` file per initial hook point). The template MUST NOT contain references to any specific organization, project, or domain.

#### Scenario: Template is universal
- **WHEN** an inspector greps `templates/extension/` for "apilize", "wertxpert", or any other client/project name
- **THEN** no matches MUST be found

#### Scenario: Template covers all initial hooks
- **WHEN** the user lists `templates/extension/hooks/`
- **THEN** the directory MUST contain `pre-pr.sh.example`, `pre-release.sh.example`, `post-archive.sh.example`, `post-capture.sh.example`, and `session-start.sh.example`

### Requirement: paths.* and worktree.* schema documentation

`docs/extension-model.md` SHALL document the full `paths.*` and `worktree.*` schemas with types, defaults, and at least one example per top-level block.

The `paths.*` block MUST cover: `paths.requirements` (string, default `requirements/`), `paths.requirements_subdirs.{vision,stakeholders,use_cases,adr}` (strings; defaults match v0.1 layout), `paths.openspec.changes` (default `openspec/changes/`), `paths.openspec.specs` (default `openspec/specs/`), `paths.raw_root` (default `raw/`), `paths.raw_subdirs.{incoming,meetings,feedback,ideas,competitors,client_boards}` (strings; defaults match `_incoming`, `meetings`, etc.).

The `worktree.*` block MUST cover: `worktree.enabled` (bool, default `false`), `worktree.base_dir` (string, default `.worktrees/`), `worktree.naming` (template, default `wt-<issue-id>`), `worktree.branch_naming` (template, default `feature/<issue-id>-<slug>`). Supported template tokens MUST be enumerated: `<issue-id>`, `<slug>`.

#### Scenario: Schema sections present
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST contain dedicated subsections for `paths.*` and `worktree.*` listing every key above with type, default, and an example

#### Scenario: Token list present
- **WHEN** a user reads the `worktree.*` schema documentation
- **THEN** the document MUST list `<issue-id>` and `<slug>` as the supported tokens, with a note that additional tokens require a documented schema bump

### Requirement: area_to_repo edge-case documentation

`docs/extension-model.md` SHALL document `area_to_repo` with all five edge cases enumerated: (1) unset entirely → current repo, (2) set but missing requested area → fail loud, (3) value `.` → current repo, (4) absolute path → used verbatim, (5) relative path → resolved against parent of current repo. At least one worked example for each edge case MUST be present.

#### Scenario: All five edge cases documented
- **WHEN** a user reads the `area_to_repo` section of `docs/extension-model.md`
- **THEN** the document MUST contain a labeled subsection or table covering all five cases above with an example for each

### Requirement: release.* schema documentation

`docs/extension-model.md` SHALL document the full `release.*` schema: `release.gates` (list of slash-command references; covered already by `drydock-extension-model`), `release.repos` (list of `{name, path, depends_on}`; multi-repo coordination), `release.block_on_labels` (list of label strings; pre-flight blocker), `release.dry_run_default` (bool; default-to-dry-run guard). For each multi-repo example, the doc MUST include a sample `depends_on` graph and the resulting topological order.

#### Scenario: All four release keys documented
- **WHEN** a user reads the `release.*` schema documentation
- **THEN** all four keys (`gates`, `repos`, `block_on_labels`, `dry_run_default`) MUST be present with type, default, and example

#### Scenario: Multi-repo example present
- **WHEN** a user reads the `release.repos` documentation
- **THEN** the document MUST contain at least one worked example with `depends_on` declarations and the implied execution order

### Requirement: github.project_fields schema documentation

`docs/extension-model.md` SHALL document `github.project_fields.{status,priority,phase,area}` with their `id` and `options` shape, including a worked example showing how to derive `id` and `options` values via `gh project field-list --format json`.

#### Scenario: Field schema and derivation example present
- **WHEN** a user reads the `github.project_fields` section
- **THEN** the document MUST show the `{id, options}` shape for each of the four fields and include a copy-pasteable `gh project field-list` invocation that produces the values

### Requirement: Templates skeleton extended with formalized schema

`templates/extension/config.yaml` SHALL contain commented examples for every key documented above: full `paths.*`, full `worktree.*`, `area_to_repo` with all five edge-case forms shown as commented examples, full `release.*` (including a multi-repo example), full `github.project_fields`. All examples MUST use universal placeholder values (no organization or product names).

#### Scenario: Templates cover formalized schema
- **WHEN** a user inspects `templates/extension/config.yaml`
- **THEN** every documented key in the formalized schema MUST appear at least once as a commented example with a universal placeholder value

#### Scenario: Templates remain universal
- **WHEN** an inspector greps `templates/extension/config.yaml` for any client/product name
- **THEN** zero matches MUST be found
