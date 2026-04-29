## ADDED Requirements

### Requirement: feature-orchestrate skill

Drydock SHALL ship a `feature-orchestrate` skill (`skills/feature-orchestrate/SKILL.md`) that encapsulates the phase-walking body invoked by `commands/feature.md`. The skill MUST be standalone-invokable (a user can call it directly without going through `/dd:feature`).

#### Scenario: Skill is discoverable
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** the `feature-orchestrate` skill MUST be invocable as a slash command

#### Scenario: Skill is listed in skills catalog
- **WHEN** a user opens `docs/skills-catalog.md`
- **THEN** the document MUST list `feature-orchestrate` under a "Feature skills" group

### Requirement: feature-clarify skill

Drydock SHALL ship a `feature-clarify` skill (`skills/feature-clarify/SKILL.md`) that produces structured clarifying questions in the closed-form shape described by `feature-orchestration` § "Structured clarifying-questions output captured into proposal.md". The skill MUST be standalone-invokable.

#### Scenario: Skill is discoverable
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** the `feature-clarify` skill MUST be invocable as a slash command

#### Scenario: Skill is listed in skills catalog
- **WHEN** a user opens `docs/skills-catalog.md`
- **THEN** the document MUST list `feature-clarify` under the "Feature skills" group with a description noting its closed-form output (recommendation + alternatives + discuss + defer options)
