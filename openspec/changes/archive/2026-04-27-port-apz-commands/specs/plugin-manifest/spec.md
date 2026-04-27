## ADDED Requirements

### Requirement: Plugin manifest at repo root

The Drydock repository SHALL include a `plugin.json` file at the repo root declaring the plugin as a Claude Code plugin. The manifest MUST include at minimum `name`, `version`, and `description` fields. The manifest MUST identify the directories from which commands, agents, and skills are auto-discovered.

#### Scenario: Manifest is valid JSON with required fields
- **WHEN** `plugin.json` is parsed
- **THEN** it MUST be valid JSON and contain non-empty `name`, `version`, and `description` fields

#### Scenario: Manifest declares component directories
- **WHEN** Claude Code loads `plugin.json`
- **THEN** the manifest MUST cause `commands/`, `skills/`, and `agents/` directories under the plugin root to be auto-discovered

### Requirement: Example configuration file

The Drydock repository SHALL include a `config.yaml.example` file at the repo root documenting every configurable knob with an inline comment explaining its purpose and default. Users MUST be able to copy the example to `config.yaml` and adjust values without consulting external documentation.

#### Scenario: Example documents every configuration key used by commands
- **WHEN** any command file reads a key from `config.yaml`
- **THEN** that key MUST appear in `config.yaml.example` with a descriptive comment

#### Scenario: Example values are universal defaults
- **WHEN** `config.yaml.example` is read
- **THEN** it MUST NOT contain Apilize-specific values (project number 2, specific field IDs, apilize repository names) as example content

### Requirement: Configuration discovery and defaults

Commands that read configuration SHALL discover `config.yaml` via `${CLAUDE_PLUGIN_ROOT}/config.yaml`. When the file is absent, commands MUST fall back to built-in defaults that are universal (no GitHub Project integration, single-repo workspace, `feature/<issue>-<slug>` branch naming, `.worktrees/` worktree directory). When the file is present but missing specific keys, individual command defaults apply per key, not an all-or-nothing fallback.

#### Scenario: Missing config.yaml does not break status command
- **WHEN** `/dd:status` is invoked in a repo with no `config.yaml`
- **THEN** the command MUST complete successfully using built-in defaults

#### Scenario: Partial config applies per-key defaults
- **WHEN** `config.yaml` declares `worktree.enabled: false` but omits `worktree.branch_naming`
- **THEN** `/dd:build:start` MUST respect the explicit `enabled: false` and MUST apply the default `feature/<issue>-<slug>` naming

### Requirement: Configurable knobs

`config.yaml` SHALL support at least the following top-level sections: `github` (org, project reference, field IDs, label mapping), `paths` (requirements subdirectory names, specs/changes locations), `worktree` (enabled, base directory, branch naming, directory naming), and `area_to_repo` (optional mapping from Area label value to repository path). The plugin MUST NOT introduce Apilize-specific keys as first-class citizens of the schema.

#### Scenario: Configuration schema has no Apilize-named keys
- **WHEN** `config.yaml.example` is read
- **THEN** no key name MUST contain the string "apilize" (case-insensitive)

### Requirement: Plugin root documentation files

The repo root SHALL include an updated `README.md` describing the plugin, its phases, and how to install it as a Claude Code plugin. The existing `CLAUDE.md` dogfooding rules MUST remain in force. `docs/migration-from-apz.md` MUST be marked authoritative (not draft) once the port lands.

#### Scenario: README describes plugin installation
- **WHEN** a new user reads `README.md`
- **THEN** the file MUST include explicit instructions for installing Drydock as a Claude Code plugin and invoking `/dd:status` as a first command

#### Scenario: Migration doc drops draft disclaimer
- **WHEN** the port is complete
- **THEN** `docs/migration-from-apz.md` MUST NOT contain the "Status: this document is a roadmap for v0.1" disclaimer
