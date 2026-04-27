# raw-ingestion Specification

## Purpose

Defines the universal raw inbox structure (`<repo>/<paths.raw_root>/_incoming/` plus five classified subdirectories), the `/dd:raw:capture` and `/dd:raw:ingest-*` commands, the source-specific configuration schema (`raw.gmail`, `raw.calendar`, `raw.drive`, `raw.notion`, `raw.linear`, `raw.github`, `raw.transcribe`), the frontmatter schema for raw entries, and the `post-capture` hook integration. Universal — sources, filters, and category sets are config-driven; the plugin code contains no organization-specific defaults.

## Requirements

### Requirement: Raw inbox directory layout

Drydock SHALL define the raw-inbox directory layout as `<repo>/<paths.raw_root>/_incoming/` for freshly captured items, plus five classified subdirectories: `meetings/`, `feedback/`, `ideas/`, `competitors/`, `client-boards/`. The default `paths.raw_root` is `raw/`. All five classified subdirectory names MUST be overridable via `paths.raw_subdirs.*` config keys.

#### Scenario: Default layout
- **WHEN** a repo has no `paths.raw_root` or `paths.raw_subdirs.*` overrides and `/dd:raw:capture` is invoked
- **THEN** the captured item MUST land at `<repo>/raw/_incoming/<filename>.md`

#### Scenario: Overridden raw root
- **WHEN** `<repo>/.drydock/config.yaml` declares `paths.raw_root: signals/` and `/dd:raw:capture` is invoked
- **THEN** the captured item MUST land at `<repo>/signals/_incoming/<filename>.md`

#### Scenario: Overridden subdir name
- **WHEN** `paths.raw_subdirs.meetings: "calls/"` is configured and `/dd:raw:process` classifies an item as `meetings`
- **THEN** the item MUST be moved into `<repo>/<raw_root>/calls/`, not `<repo>/<raw_root>/meetings/`

### Requirement: Raw entry frontmatter schema

Every file written into the raw inbox by `/dd:raw:capture` or `/dd:raw:ingest-*` SHALL contain YAML frontmatter with the following required keys: `source` (one of `gmail|calendar|drive|notion|linear|github|manual`), `captured_at` (ISO 8601 datetime when Drydock filed the item), `dedup_key` (deterministic per-item identifier; collision implies duplicate). Optional keys MAY include `parties`, `links`, `attachments`, `traces_to`, `original_at`. The schema MUST be documented in `docs/extension-model.md` § raw.

#### Scenario: Required keys present
- **WHEN** any `/dd:raw:capture` or `/dd:raw:ingest-*` command writes a new item file
- **THEN** the file's frontmatter MUST contain `source`, `captured_at`, and `dedup_key`

#### Scenario: Source value matches an allowed enum
- **WHEN** Drydock files a raw item
- **THEN** the `source` field MUST be exactly one of: `gmail`, `calendar`, `drive`, `notion`, `linear`, `github`, `manual`

#### Scenario: dedup_key uses source-stable identifier
- **WHEN** `/dd:raw:ingest-gmail` files a Gmail message with message-id `<abc@gmail.com>`
- **THEN** the file's `dedup_key` MUST be `gmail:<abc@gmail.com>` (stable across re-runs)

### Requirement: /dd:raw:capture command

The `/dd:raw:capture` command SHALL accept user-provided content (interactive prompt for source, body, parties, links) and write a single new item to `<repo>/<paths.raw_root>/_incoming/<YYYY-MM-DD>-<slug>.md` with required frontmatter. The command MUST invoke the `post-capture` lifecycle hook for the filed item.

#### Scenario: Manual capture lands in _incoming/
- **WHEN** `/dd:raw:capture` is invoked and the user enters a meeting note about a call with a customer
- **THEN** a new file MUST be created at `<repo>/<paths.raw_root>/_incoming/<YYYY-MM-DD>-<slug>.md` with `source: manual`, `captured_at` set to the invocation time, and a non-empty `dedup_key`

#### Scenario: Post-capture hook fires after capture
- **WHEN** `/dd:raw:capture` files an item and `<repo>/.drydock/hooks/post-capture.sh` is present and executable
- **THEN** the hook MUST be invoked exactly once with the new item's path in its JSON stdin payload

### Requirement: /dd:raw:ingest-* commands per source

Drydock SHALL ship six bulk-ingestion commands: `/dd:raw:ingest-gmail`, `/dd:raw:ingest-calendar`, `/dd:raw:ingest-drive`, `/dd:raw:ingest-notion`, `/dd:raw:ingest-linear`, `/dd:raw:ingest-github`. Each command MUST: (1) read its filter set from the corresponding `raw.<source>.*` config block; (2) verify the corresponding MCP server is connected; (3) pull matching items via the MCP; (4) write each item to `<repo>/<paths.raw_root>/_incoming/` with the universal frontmatter schema; (5) invoke the `post-capture` hook per filed item; (6) skip items whose `dedup_key` already exists in the inbox or in any classified subdirectory.

#### Scenario: Missing MCP fails fast
- **WHEN** `/dd:raw:ingest-gmail` is invoked and the Gmail MCP server is not connected
- **THEN** the command MUST exit with a clear "Gmail MCP is not connected" message naming the install path; no items MUST be written

#### Scenario: Filter set comes entirely from config
- **WHEN** `/dd:raw:ingest-gmail` is invoked and `raw.gmail.query: "is:unread label:client/foo"` is configured
- **THEN** the command MUST use exactly that query against the Gmail MCP; no hardcoded filter strings MUST appear in the command file

#### Scenario: Dedup prevents re-ingestion
- **WHEN** `/dd:raw:ingest-gmail` runs twice in a row over the same Gmail messages with no source-side changes
- **THEN** the second run MUST file zero new items; existing items MUST NOT be overwritten

#### Scenario: Per-item post-capture hook
- **WHEN** `/dd:raw:ingest-notion` files three new items in one run and the post-capture hook is present
- **THEN** the hook MUST be invoked three times (once per item)

### Requirement: /dd:raw:transcribe command

The `/dd:raw:transcribe` command SHALL accept a raw entry filename (with an `attachments` frontmatter field pointing to an audio/video file), invoke the configured transcription provider (`raw.transcribe.provider`, `raw.transcribe.model`), append the transcript to the entry body, and move the entry to `<repo>/<paths.raw_root>/<paths.raw_subdirs.meetings>/`.

#### Scenario: Transcript appended and entry classified
- **WHEN** `/dd:raw:transcribe raw/_incoming/2026-04-20-strategy-call.md` is invoked, `attachments: [drive:abc/recording.mp4]` is present, and the transcription provider returns a transcript
- **THEN** the file's body MUST be updated to include the transcript under a `## Transcript` section, and the file MUST be moved into the meetings subdirectory

#### Scenario: Missing transcription provider config
- **WHEN** `/dd:raw:transcribe` is invoked and `raw.transcribe.provider` is unset
- **THEN** the command MUST exit with a clear "transcription provider not configured" message and the entry MUST remain in place

### Requirement: raw.* configuration schema

Drydock SHALL document a `raw.*` configuration schema under `docs/extension-model.md` and provide commented examples in `templates/extension/config.yaml`. The schema MUST cover at minimum: `raw.gmail.{filters,query,labels_to_track,since_days}`, `raw.calendar.{calendar_ids,look_back_days,look_ahead_days}`, `raw.drive.{folder_ids,file_types,since_days}`, `raw.notion.{databases}`, `raw.linear.{teams,filter}`, `raw.github.{repos,since_days}`, `raw.transcribe.{provider,model}`, and `raw.classifier.{categories}` (consumed by `raw-classification`).

#### Scenario: Schema documentation present
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST contain a `raw.*` section listing all source keys above with type, default, and one-sentence purpose

#### Scenario: Template ships every source commented
- **WHEN** a user inspects `templates/extension/config.yaml`
- **THEN** the file MUST contain commented examples for every `raw.<source>.*` key documented in the schema, with universal example values (no real client names)

### Requirement: Universal sources only — no organization-specific defaults

Command files under `commands/raw/` and the `raw-classifier` agent MUST NOT contain hardcoded references to specific organizations, clients, or product names. All source-specific values (filters, IDs, queries, label names) live in the consuming repo's `<repo>/.drydock/config.yaml` only.

#### Scenario: Universality grep
- **WHEN** an inspector greps `commands/raw/`, `agents/raw-classifier.md`, and `skills/raw-*/` for any client/product name from past APZ usage
- **THEN** zero matches MUST be found
