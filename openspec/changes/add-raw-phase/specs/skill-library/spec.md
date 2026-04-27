## ADDED Requirements

### Requirement: Raw skills shipped

Drydock SHALL ship the following skills to support the raw phase, each as a `skills/<name>/SKILL.md` directory with optional `templates/` and `examples/`: `raw-capture`, `raw-process`, `raw-ingest-gmail`, `raw-ingest-calendar`, `raw-ingest-drive`, `raw-ingest-notion`, `raw-ingest-linear`, `raw-ingest-github`, `raw-transcribe`. Each skill MUST be standalone-invokable and MUST contain no organization-specific content.

#### Scenario: All nine raw skills present
- **WHEN** an inspector lists `skills/`
- **THEN** the nine raw-* skill directories MUST be present alongside existing skills

#### Scenario: Each raw skill is standalone-invokable
- **WHEN** the user invokes `/raw-capture` directly without going through `/dd:raw:capture`
- **THEN** the skill MUST execute correctly using the same logic the wrapper command relies on

#### Scenario: Skills contain no organization-specific content
- **WHEN** an inspector greps `skills/raw-*/` for "apilize", "wertxpert", "intreal", or any other client/product name
- **THEN** zero matches MUST be found
