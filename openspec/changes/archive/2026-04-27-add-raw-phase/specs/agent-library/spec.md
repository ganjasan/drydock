## ADDED Requirements

### Requirement: raw-classifier agent shipped

Drydock SHALL ship the `raw-classifier` subagent at `agents/raw-classifier.md`. The agent classifies raw inbox items into categories per the `raw-classification` capability. It MUST be invocable via the Agent tool with `subagent_type: dd:raw-classifier` (or the equivalent fully-qualified name per the Drydock agent namespace).

#### Scenario: Agent file present after change applies
- **WHEN** an inspector lists `agents/`
- **THEN** `raw-classifier.md` MUST be present alongside the existing `code-architect`, `code-explorer`, `code-reviewer`, `release-coordinator`, and `traces-linter` agents

#### Scenario: Agent invocable via the Agent tool
- **WHEN** `/dd:raw:process` runs and invokes the classifier via Agent tool with `subagent_type: dd:raw-classifier`
- **THEN** the agent MUST be resolved and execute against the provided inbox items

#### Scenario: Agent contains no organization-specific content
- **WHEN** an inspector greps `agents/raw-classifier.md` for "apilize", "wertxpert", "intreal", or any other client/product name
- **THEN** zero matches MUST be found
