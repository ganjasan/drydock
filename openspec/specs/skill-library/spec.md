# skill-library Specification

## Purpose
TBD - created by archiving change port-apz-commands. Update Purpose after archive.
## Requirements
### Requirement: Skill directory layout

Each Drydock skill SHALL live in its own kebab-case directory under `skills/` and MUST contain a `SKILL.md` file. Skills MAY include `templates/` and `examples/` subdirectories for supporting material. The `SKILL.md` frontmatter MUST contain `name` and `description` fields, and MAY contain `allowed-tools` when the skill restricts tool access.

#### Scenario: Skill file placement
- **WHEN** a new skill named `foo-bar` is added to Drydock
- **THEN** it MUST be at `skills/foo-bar/SKILL.md` (kebab-case directory, uppercase filename)

#### Scenario: Skill frontmatter is valid YAML
- **WHEN** any skill in `skills/` is loaded by Claude Code
- **THEN** its `SKILL.md` frontmatter MUST parse as valid YAML with `name` and `description` present

### Requirement: Required skills for v0.1

Drydock v0.1 SHALL ship the following skills: `vision-and-scope`, `use-case`, `stakeholder-profile`, `requirements-elicitation`, `requirements-review`, `adr`, `openspec-new-change`, `openspec-continue-change`, `openspec-apply-change`, `openspec-ff-change`, `openspec-explore`, `openspec-verify-change`, `openspec-archive-change`, `openspec-sync-specs`, `openspec-bulk-archive`. Each skill listed in `docs/skills-catalog.md` MUST have a corresponding directory and `SKILL.md`.

#### Scenario: Catalog matches filesystem
- **WHEN** `docs/skills-catalog.md` names skill `X`
- **THEN** `skills/X/SKILL.md` MUST exist

### Requirement: Skills are standalone-invokable

Each skill SHALL be invokable directly by the user without going through a Drydock command wrapper. The skill body MUST NOT assume invocation context (e.g. that an OpenSpec change already exists) when the same skill can reasonably be used outside a Drydock workflow. When a skill requires context that may be absent, the skill MUST detect the absence and either prompt the user or produce a graceful no-op.

#### Scenario: ADR skill invoked without Drydock workflow
- **WHEN** the `adr` skill is invoked in a repo that has no `requirements/adr/` directory
- **THEN** the skill MUST offer to create the directory rather than failing

#### Scenario: Skill content is not duplicated in command file
- **WHEN** the command file `commands/req/adr.md` wraps the `adr` skill
- **THEN** the command file MUST delegate the prompt body to the skill, not copy its contents

### Requirement: Skill → command wrapper convention

For each skill with a corresponding `/dd:*` command, the command file SHALL be a thin wrapper that parses arguments, resolves paths via `config.yaml`, and then invokes the skill. The command wrapper MUST NOT re-implement skill logic.

#### Scenario: Command wrapper delegates to skill
- **WHEN** `/dd:req:adr "topic"` is invoked
- **THEN** `commands/req/adr.md` MUST resolve the target directory via config and then delegate to the `adr` skill for the prompt body

### Requirement: Requirements skills use Wiegers conventions

The skills `vision-and-scope`, `use-case`, `stakeholder-profile`, `requirements-elicitation`, and `requirements-review` SHALL follow the conventions described in Wiegers & Beatty, *Software Requirements, 3rd Edition*. Each skill MUST produce output that is either a Wiegers-form document or a review report keyed to Wiegers quality criteria (clear, complete, consistent, feasible, necessary, prioritized, testable, unambiguous).

#### Scenario: Requirements review reports against Wiegers criteria
- **WHEN** the `requirements-review` skill processes a requirements file
- **THEN** the output report MUST explicitly evaluate each of the Wiegers criteria and flag any requirement that fails at least one

### Requirement: OpenSpec skills wrap the openspec CLI

The `openspec-*` skills SHALL invoke the `openspec` CLI for all change-management operations (create, status, instructions, archive, sync). They MUST NOT duplicate CLI behavior by reading or writing `openspec/` files directly when a CLI command for the same operation exists.

#### Scenario: Fast-forward skill uses CLI for scaffolding
- **WHEN** the `openspec-ff-change` skill is invoked
- **THEN** it MUST invoke `openspec new change` and `openspec instructions` commands rather than manually creating `.openspec.yaml`

### Requirement: Raw skills shipped

Drydock SHALL ship the following skills supporting the raw phase, each as a `skills/<name>/SKILL.md` directory with optional `templates/` and `examples/`: `raw-capture`, `raw-process`, `raw-ingest-gmail`, `raw-ingest-calendar`, `raw-ingest-drive`, `raw-ingest-notion`, `raw-ingest-linear`, `raw-ingest-github`, `raw-transcribe`. Each skill MUST be standalone-invokable and MUST contain no organization-specific content.

#### Scenario: All nine raw skills present
- **WHEN** an inspector lists `skills/`
- **THEN** the nine `raw-*` skill directories MUST be present alongside existing skills

#### Scenario: Each raw skill is standalone-invokable
- **WHEN** the user invokes `/raw-capture` directly without going through `/dd:raw:capture`
- **THEN** the skill MUST execute correctly using the same logic the wrapper command relies on

#### Scenario: Skills contain no organization-specific content
- **WHEN** an inspector greps `skills/raw-*/` for any client/product name (e.g. `apilize`, `wertxpert`, `intreal`)
- **THEN** zero matches MUST be found

