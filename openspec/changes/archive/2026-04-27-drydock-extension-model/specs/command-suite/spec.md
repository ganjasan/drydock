## ADDED Requirements

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
