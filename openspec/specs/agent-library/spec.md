# agent-library Specification

## Purpose
TBD - created by archiving change port-apz-commands. Update Purpose after archive.
## Requirements
### Requirement: Agent file placement and format

Each Drydock subagent SHALL be a single Markdown file under `agents/` with kebab-case filename. The file MUST begin with YAML frontmatter containing at minimum `name`, `description`, and `tools` fields, followed by the agent's system prompt body.

#### Scenario: Agent frontmatter contains required fields
- **WHEN** any file in `agents/` (other than `README.md`) is loaded
- **THEN** its frontmatter MUST contain non-empty `name`, `description`, and `tools` fields

### Requirement: Required agents

Drydock SHALL ship the following subagents: `code-reviewer`, `code-explorer`, `code-architect`, `traces-linter`, `release-coordinator`, `raw-classifier`. The set MAY grow in subsequent versions; existing agents MUST NOT be removed without a major version bump.

#### Scenario: Agent set matches docs
- **WHEN** `docs/skills-catalog.md` lists an agent in the sub-agents section
- **THEN** the corresponding file MUST exist at `agents/<name>.md`

#### Scenario: raw-classifier is shipped
- **WHEN** an inspector lists `agents/`
- **THEN** `raw-classifier.md` MUST be present alongside the other required agents

#### Scenario: raw-classifier is invocable via the Agent tool
- **WHEN** `/dd:raw:process` runs and invokes the classifier via the Agent tool with `subagent_type: dd:raw-classifier`
- **THEN** the agent MUST be resolved and execute against the provided inbox items

#### Scenario: raw-classifier contains no organization-specific content
- **WHEN** an inspector greps `agents/raw-classifier.md` for any client/product name (e.g. `apilize`, `wertxpert`, `intreal`)
- **THEN** zero matches MUST be found

### Requirement: Traces-linter agent verifies bidirectional references

The `traces-linter` agent SHALL scan requirement, ADR, use-case, and OpenSpec change artifacts for `traces_to` frontmatter fields and MUST report any reference that is not resolved in both directions (forward link present but no inverse, or vice versa). The agent MUST distinguish between orphaned requirements (no reverse link from any implementation artifact) and broken links (forward link to a non-existent target).

#### Scenario: Detects orphaned requirement
- **WHEN** `traces-linter` runs against a repo with an ADR whose `traces_to.requirements` field names `REQ-042` that is not referenced by any epic, change, or use-case
- **THEN** the agent MUST report `REQ-042` as orphaned with the ADR as its sole referrer

#### Scenario: Detects broken forward link
- **WHEN** an ADR's `traces_to.epic` field names an issue that does not exist in the configured repo
- **THEN** the agent MUST report the link as broken and identify the containing ADR

### Requirement: Release-coordinator is opt-in

The `release-coordinator` agent SHALL be invoked by `/dd:ship:release` only when `config.yaml` declares multiple repositories with a dependency order. In single-repo mode the agent MUST NOT be invoked, and `/dd:ship:release` MUST complete without referencing it.

#### Scenario: Single-repo release skips coordinator
- **WHEN** `/dd:ship:release` runs in a repo whose `config.yaml` has no multi-repo declaration
- **THEN** the `release-coordinator` agent MUST NOT be spawned

#### Scenario: Multi-repo release invokes coordinator
- **WHEN** `/dd:ship:release` runs with `config.yaml` declaring two or more repos with a `depends_on` ordering
- **THEN** the `release-coordinator` agent MUST be spawned to determine release order

### Requirement: Code-exploration agents distinguish from Claude Code built-ins

The `code-reviewer`, `code-explorer`, and `code-architect` agents SHALL each have a description in their frontmatter that makes clear how they differ from Claude Code's built-in agents of similar name. Drydock-flavored agents MUST apply Drydock conventions (e.g. Wiegers traceability checks, OpenSpec artifact awareness) that built-ins do not.

#### Scenario: Code-reviewer description references OpenSpec awareness
- **WHEN** the frontmatter of `agents/code-reviewer.md` is read
- **THEN** the `description` field MUST mention that the agent reviews code against the active OpenSpec change's tasks and specs

### Requirement: Agents declare their allowed tool set

Each agent's frontmatter SHALL declare its `tools` allowlist explicitly. Agents that only read MUST NOT list `Write` or `Edit`; agents that must execute shell commands MUST list `Bash` explicitly. No agent MAY list `*` or an unbounded wildcard.

#### Scenario: Read-only agent has no write tools
- **WHEN** `traces-linter.md` is loaded
- **THEN** its `tools` field MUST include `Read`, `Glob`, `Grep` and MUST NOT include `Write` or `Edit`

