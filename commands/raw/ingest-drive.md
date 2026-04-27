---
description: Pull Google Drive files (recordings, docs) into the raw inbox; stores metadata, transcribe later via /dd:raw:transcribe
allowed-tools: Bash, Read, Write
---

Bulk-ingest Drive files as raw items via the Google Drive MCP. Folders and file types come from `raw.drive.*` config. Recordings are stored as metadata-only entries — transcription happens explicitly via `/dd:raw:transcribe`.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. MCP detection

Verify Google Drive MCP is connected. If absent: `ERROR: Google Drive MCP is not connected.` Exit non-zero.

### 2. Read filter config

```bash
folders="$(cfg_array_get raw.drive.folder_ids)"
file_types="$(cfg_array_get raw.drive.file_types)"   # e.g. video/mp4, audio/m4a, application/vnd.google-apps.document
since_days="$(cfg_get raw.drive.since_days)"          # default 7
```

If `folders` is empty, abort: "raw.drive.folder_ids must be configured."

### 3. Pull files

For each folder, call Drive MCP to list files modified in the last `since_days` and matching any of `file_types`. Fetch metadata only (no body — large files would balloon the inbox).

### 4. For each file — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

a. **`dedup_key`**: `drive:<file-id>`.

b. **Dedup**: skip if exists.

c. **Filename**: `${modified_date:0:10}_drive_$(fm_slug "${file_name}").md`.

d. **Body**: a placeholder describing the file (mime type, size, owner, modified time, link). For Docs/Sheets, optionally include the first ~500 chars via the MCP. For recordings, only metadata — invite the user to run `/dd:raw:transcribe <path>` next.

e. **Frontmatter**:

```yaml
---
source: drive
captured_at: <ISO 8601 UTC, now>
dedup_key: drive:<file-id>
captured_by: claude-code:/dd:raw:ingest-drive
original_at: <file modifiedTime in ISO 8601>
parties: [<owner-email>]
links: [<webViewLink>]
attachments: [<drive:/file-id-resolved-path>]
topics: []
proposed_category: ""
drive:
  file_id: <id>
  mime_type: <mime>
  size_bytes: <int>
  is_recording: <bool>     # true for video/audio mime types
traces_to: {}
---

# <file name>

**Drive link:** <webViewLink>
**Type:** <mime>
**Size:** <human-readable>
**Owner:** <owner-email>

<placeholder or first ~500 chars of body>

<!-- For recordings, run: /dd:raw:transcribe <this-path> -->
```

f. **Post-capture hook** per item.

### 5. Report

```
Ingested <N> Drive file(s); skipped <M> existing (dedup); <K> errors
Recordings: <R>  (run /dd:raw:transcribe to fold transcripts in)
```

## Guardrails

- Folder IDs and file types come only from `raw.drive.*` config.
- Recordings are NOT auto-transcribed here — that's a separate explicit operation (`/dd:raw:transcribe`) because of cost.
- Dedup by stable file-id; never overwrite.
- Do not pull file bodies wholesale — metadata + small preview only.
