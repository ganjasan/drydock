## Why

The Drydock workflow is `Raw → Requirements → Plan → Build → Ship` (ADR-0004), but `Raw` is the only phase Drydock does not yet implement. External signals — client emails, meeting notes, calendar events, Notion pages, Linear issues, upstream GitHub issues — are the left edge of every project the owner runs, not an Apilize specialty. The capability exists today as `/apz:raw:*` in the soon-to-be-retired APZ plugin, with all source-specific defaults baked into command files. With the extension model now in place (change `drydock-extension-model`), the right move is to port these commands to Drydock, generalize their defaults into the `raw.*` config schema, and move the `raw-classifier` agent into Drydock alongside them. This unblocks `retire-apz`.

## What Changes

- **NEW** `/dd:raw:capture` — manual entry of an external signal into `<repo>/raw/_incoming/` with structured frontmatter (source, date, parties, body or link).
- **NEW** `/dd:raw:process` — classify items in `_incoming/` into `raw/meetings/`, `raw/feedback/`, `raw/ideas/`, `raw/competitors/`, `raw/client-boards/`; dedup; cross-link to existing requirements/issues; suggest backlog items.
- **NEW** `/dd:raw:ingest-gmail`, `/dd:raw:ingest-calendar`, `/dd:raw:ingest-drive`, `/dd:raw:ingest-notion`, `/dd:raw:ingest-linear`, `/dd:raw:ingest-github` — bulk pulls from external sources, filtered per `raw.<source>.*` config keys; landing items into `_incoming/` with the same frontmatter shape.
- **NEW** `/dd:raw:transcribe` — transcribe an audio/video file referenced by a raw entry (typically a Meet recording) and fold the transcript into `raw/meetings/`.
- **NEW** `agents/raw-classifier.md` — subagent ported from APZ with all Apilize-specific category lists generalized into config-driven defaults.
- **NEW** Skills under `skills/`: `raw-capture`, `raw-process`, `raw-ingest-gmail`, `raw-ingest-calendar`, `raw-ingest-drive`, `raw-ingest-notion`, `raw-ingest-linear`, `raw-ingest-github`, `raw-transcribe`. Each follows the standard `SKILL.md` convention.
- **NEW** `raw.*` configuration schema:
  - `paths.raw_root` (default `raw/`), `paths.raw_subdirs.{incoming,meetings,feedback,ideas,competitors,client_boards}` with documented defaults.
  - `raw.gmail.{filters[],query,labels_to_track[],since_days}` — Gmail MCP filter set.
  - `raw.calendar.{calendar_ids[],look_back_days,look_ahead_days}` — Google Calendar MCP.
  - `raw.drive.{folder_ids[],file_types[],since_days}` — Google Drive MCP.
  - `raw.notion.{databases[]}` — list of `{id, label}` for Notion MCP.
  - `raw.linear.{teams[],filter}` — Linear MCP.
  - `raw.github.{repos[],since_days}` — external repos to watch for issues/comments.
  - `raw.transcribe.{provider, model}` — transcription back-end choice.
- **NEW** Frontmatter schema for raw entries documented in `docs/extension-model.md` § raw: required `source`, `captured_at`, `dedup_key`; optional `parties`, `links`, `attachments`, `traces_to`.
- **MODIFIED** `/dd:raw:capture` and `/dd:raw:ingest-*` invoke the `post-capture` lifecycle hook for each filed item, using the protocol established in `drydock-extension-model`.
- **MODIFIED** `/dd:status` and `/dd:next` recognize the raw inbox: status reports a one-line summary of `_incoming/` count; next suggests `/dd:raw:process` when the inbox is non-empty.
- Source-specific defaults stay **out** of command files. Every Apilize-specific filter that lived inside APZ commands (Gmail labels naming clients, Notion DB IDs, Linear team filters) is removed in favor of `raw.*` config keys with universal documented defaults.

## Capabilities

### New Capabilities

- `raw-ingestion`: the raw inbox structure (`raw/_incoming/`, classified subdirs), the `/dd:raw:capture` and `/dd:raw:ingest-*` commands, the source-config schema (`raw.gmail`, `raw.calendar`, `raw.drive`, `raw.notion`, `raw.linear`, `raw.github`, `raw.transcribe`), the frontmatter schema for raw entries, and the `post-capture` hook integration for each filed item.
- `raw-classification`: the `/dd:raw:process` command, the `raw-classifier` agent, the classification rules (categories and routing), the deduplication strategy, the cross-link heuristic to existing requirements and GitHub issues, and the backlog-suggestion output format.

### Modified Capabilities

- `agent-library`: add `raw-classifier` to the shipped agent set.
- `skill-library`: add the nine raw skills to the shipped skill set.
- `command-suite`: extend the namespace with `/dd:raw:*` commands; update `/dd:status` and `/dd:next` to recognize the raw inbox.

## Impact

- **Code:** new `commands/raw/` directory with nine command files; new `agents/raw-classifier.md`; new `skills/raw-*/SKILL.md` directories.
- **Docs:** `docs/extension-model.md` extended with the `raw.*` schema and frontmatter doc; `docs/skills-catalog.md` raw-section flipped from "*(planned)*" to "shipped"; `docs/methodology.md` and `docs/workflow.md` already describe the raw phase.
- **Templates:** `templates/extension/config.yaml` extended with the `raw.*` block (commented).
- **Specs:** new `raw-ingestion`, `raw-classification` specs; deltas against `agent-library`, `skill-library`, `command-suite`.
- **Tests:** verify each ingest command produces well-formed frontmatter; verify `process` classifies a fixture inbox correctly; verify dedup_key collisions are merged not duplicated; verify post-capture hook fires for each filed item.
- **Downstream:** `retire-apz` becomes possible — Apilize-hub can switch from `/apz:raw:*` to `/dd:raw:*` and move all filter content to its `<repo>/.drydock/config.yaml`.
- **Breaking-change scope:** none for Drydock itself (this is purely additive). For APZ users specifically, the migration is documented and handled in `retire-apz`.
