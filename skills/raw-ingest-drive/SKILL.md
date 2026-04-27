---
name: raw-ingest-drive
description: Pull Google Drive files (recordings, docs) into the raw inbox via Drive MCP; metadata only — transcription is explicit via /dd:raw:transcribe. Folders come from raw.drive.* config. Standalone-invokable; also wrapped by /dd:raw:ingest-drive.
---

You are the raw-ingest-drive skill. Bulk-ingest Drive file metadata as raw items. Recordings stay metadata-only — transcription is explicit and separate via `raw-transcribe`.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **MCP detection**: Google Drive MCP must be connected. Absent → fail with install guidance.

2. **Read config**:
   ```bash
   folders="$(cfg_array_get raw.drive.folder_ids)"
   file_types="$(cfg_array_get raw.drive.file_types)"
   since_days="$(cfg_get raw.drive.since_days)"   # default 7
   ```
   Empty `folders` → abort: "raw.drive.folder_ids must be configured."

3. **Pull file metadata** for files in each folder modified in the last `since_days` matching any of `file_types`. Do NOT fetch file bodies wholesale — metadata + a small preview only (first ~500 chars for Docs/Sheets).

4. **For each file**:
   - `dedup_key`: `drive:<file-id>`. Skip if exists.
   - Filename: `${modified_date:0:10}_drive_$(fm_slug "${file_name}").md`.
   - Body: file name, drive link, mime, size, owner, then either preview (Docs/Sheets) or "recording — run /dd:raw:transcribe to fold transcript" placeholder.
   - Frontmatter: `source: drive`, `captured_at`, `dedup_key`, `original_at: <modifiedTime>`, `parties: [owner]`, `links: [webViewLink]`, `attachments: [drive:<file-id>]`, `drive.{file_id, mime_type, size_bytes, is_recording}`, `traces_to: {}`.
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "drive"}`.

5. **Report**: ingested / skipped, plus a count of recordings (so the user knows how many `/dd:raw:transcribe` invocations are pending).

## Guardrails

- Folder IDs and file types from `raw.drive.*` only.
- Recordings: metadata only — transcription is a separate explicit operation.
- Dedup by stable file-id.
- Do not fetch file bodies wholesale — preview only.
