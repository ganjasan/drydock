## ADDED Requirements

### Requirement: /dd:raw:* command namespace

Drydock SHALL expose the following commands under the `/dd:raw:` namespace, each as a Markdown file under `commands/raw/`: `capture.md`, `process.md`, `ingest-gmail.md`, `ingest-calendar.md`, `ingest-drive.md`, `ingest-notion.md`, `ingest-linear.md`, `ingest-github.md`, `transcribe.md`. Each command MUST follow the standard frontmatter convention (description, allowed-tools).

#### Scenario: All raw commands discover correctly
- **WHEN** Claude Code loads the Drydock plugin
- **THEN** `/dd:raw:capture`, `/dd:raw:process`, `/dd:raw:ingest-gmail`, `/dd:raw:ingest-calendar`, `/dd:raw:ingest-drive`, `/dd:raw:ingest-notion`, `/dd:raw:ingest-linear`, `/dd:raw:ingest-github`, and `/dd:raw:transcribe` MUST all be invocable

#### Scenario: Command files contain no organization-specific content
- **WHEN** an inspector greps `commands/raw/` for "apilize", "wertxpert", "intreal", or any other client/product name
- **THEN** zero matches MUST be found

### Requirement: Status command summarizes raw inbox

The `/dd:status` command SHALL include a one-line "Raw inbox" summary reporting the count of files in `<repo>/<paths.raw_root>/_incoming/` and (if available) the timestamp of the most recent `/dd:raw:process` invocation.

#### Scenario: Inbox count reported when present
- **WHEN** `<repo>/raw/_incoming/` contains 12 files and `/dd:status` is invoked
- **THEN** the output MUST include a line like `Raw inbox: 12 in _incoming` (or equivalent format under 80 characters)

#### Scenario: No raw root configured
- **WHEN** the repo has no `paths.raw_root` configured AND no default `raw/` directory exists
- **THEN** `/dd:status` MUST omit the Raw inbox line entirely (rather than reporting `0 in _incoming`)

### Requirement: Next command suggests process when inbox is non-empty

The `/dd:next` command SHALL include in its decision logic: if `<repo>/<paths.raw_root>/_incoming/` contains one or more files, suggest `/dd:raw:process` as the next action (with priority above starting new build work). The suggestion MUST name the file count.

#### Scenario: Non-empty inbox prioritized
- **WHEN** `_incoming/` contains 3 files, no active OpenSpec change exists, and `/dd:next` is invoked
- **THEN** the suggestion MUST be `/dd:raw:process` and MUST include the count `3`

#### Scenario: Empty inbox does not trigger raw suggestion
- **WHEN** `_incoming/` is empty
- **THEN** `/dd:next` MUST NOT mention `/dd:raw:process`; the existing decision logic for changes/PRs/issues applies
