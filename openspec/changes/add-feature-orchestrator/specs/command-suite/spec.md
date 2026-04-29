## ADDED Requirements

### Requirement: /dd:feature top-level command

Drydock SHALL expose `/dd:feature` as a top-level command (file: `commands/feature.md`) alongside `/dd:status` and `/dd:next`. The command MUST be listed in the "Top-level" table of `commands/README.md` with a one-liner describing its umbrella role.

#### Scenario: /dd:feature is discoverable
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** `/dd:feature` MUST be invocable

#### Scenario: README lists /dd:feature
- **WHEN** a user opens `commands/README.md`
- **THEN** the "Top-level" table MUST contain a row for `/dd:feature` with a one-line description naming it as an end-to-end shortcut

### Requirement: Status and Next integrate feature flow position

`/dd:status` and `/dd:next` SHALL use `lib/feature_state.sh::dd_feature_position` so that an in-flow workspace surfaces its current phase. `/dd:next` MUST suggest `/dd:feature` (with the resume hint) when an in-flow state is detected, with priority above starting new build work.

#### Scenario: Status reports active flow position
- **WHEN** an in-flow workspace exists (issue + change + branch present, no PR yet) and `/dd:status` is invoked
- **THEN** the status output MUST include a one-line "Active feature flow: phase <N> (<phase-name>)"

#### Scenario: Next suggests resuming the flow
- **WHEN** an in-flow workspace exists and `/dd:next` is invoked
- **THEN** the suggested action MUST be `/dd:feature` (or the per-phase command for the next pending step), not a generic "start a new feature" suggestion
