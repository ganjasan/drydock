---
description: Transcribe an audio/video file referenced in a raw entry (typically a Drive recording) and fold the transcript into raw/meetings/
argument-hint: "<raw-entry-path>"
allowed-tools: Bash, Read, Write, Edit
---

Convert a recording referenced from a raw entry into a transcript and fold it into the meetings subfolder. Provider and model come from `raw.transcribe.*` config.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. Resolve target

`$ARGUMENTS` is the path to a raw entry (e.g. from `_incoming/` or `meetings/`). The entry's frontmatter must include `attachments` listing at least one audio/video reference (typically `drive:<file-id>` or a local path).

If no `attachments` field, exit: "no attachments referenced in <path>; nothing to transcribe."

### 2. Read transcription config

```bash
provider="$(cfg_get raw.transcribe.provider)"   # e.g. openai-whisper, google-stt, deepgram
model="$(cfg_get raw.transcribe.model)"          # provider-specific model name
```

If `provider` is unset, exit: "raw.transcribe.provider not configured. See docs/extension-model.md § raw.transcribe."

### 3. Resolve attachment

For each attachment:

- `drive:<file-id>` → use the Google Drive MCP to fetch the media bytes (or a streaming URL if the provider supports it).
- Local path → read directly.

If MCP needed but absent, fail loudly with install guidance.

### 4. Run transcription

Invoke the configured provider with the media. Capture the transcript text plus any structural information (speaker turns, timestamps) the provider returns.

This may take minutes for long recordings. Show progress to the user.

### 5. Fold transcript into the entry

Edit the raw entry (Edit tool):

- Append a `## Transcript` section to the body containing the transcript (preserve speaker turns / timestamps if available).
- Update frontmatter:
  - Set `proposed_category: meetings` (if not already).
  - Add `transcribed_at: <ISO 8601>` and `transcribe.{provider, model}` for provenance.

### 6. Move to meetings/

```bash
raw_root="$(cfg_get paths.raw_root)"
meetings_subdir="$(cfg_get paths.raw_subdirs.meetings)"
target_dir="<repo-root>/${raw_root}/${meetings_subdir}"
```

`git mv <current-path> ${target_dir}/<filename>` (preserve filename or normalize per the meetings convention `YYYY-MM-DD_<topic>.md` if the user opts in).

### 7. Report

```
Transcribed: <attachment>  (<duration>, <provider>:<model>)
Folded into: <relative-path>
Length: <approx word count>
Next: /dd:raw:process     (if transcript reveals actionable items)
```

## Guardrails

- Never call a transcription provider without `raw.transcribe.provider` explicitly set.
- Preserve provenance: `transcribe.{provider, model}` and `transcribed_at` in frontmatter.
- For multi-attachment entries, transcribe each and concatenate transcripts under separated headers.
- Long-running operation — surface progress to the user; do not run silently.
