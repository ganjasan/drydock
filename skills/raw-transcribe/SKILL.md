---
name: raw-transcribe
description: Transcribe an audio/video file referenced in a raw entry (typically a Drive recording) and fold the transcript into raw/meetings/. Provider and model come from raw.transcribe.* config. Standalone-invokable; also wrapped by /dd:raw:transcribe.
---

You are the raw-transcribe skill. Convert a recording referenced from a raw entry into a transcript and fold it into the meetings subfolder.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **Resolve target**: input is a path to a raw entry whose frontmatter `attachments` lists at least one media reference (`drive:<file-id>` or local path). No attachments → exit: "no attachments referenced in <path>; nothing to transcribe."

2. **Read transcription config**:
   ```bash
   provider="$(cfg_get raw.transcribe.provider)"
   model="$(cfg_get raw.transcribe.model)"
   ```
   `provider` unset → exit: "raw.transcribe.provider not configured. See docs/extension-model.md § raw.transcribe."

3. **Resolve attachment**: `drive:<file-id>` → fetch via Drive MCP (or streaming URL if provider supports). Local path → read directly. Required MCP absent → fail with install guidance.

4. **Run transcription**: invoke configured provider with media. Capture transcript text plus structural markers (speaker turns, timestamps) where the provider supports them. Surface progress to the user — long operation.

5. **Fold into entry**: Edit raw entry. Append `## Transcript` to body containing the transcript (preserve speaker turns / timestamps). Update frontmatter: set `proposed_category: meetings` (if not set), add `transcribed_at: <ISO 8601>` and `transcribe.{provider, model}` for provenance.

6. **Move to meetings/**: `git mv <current-path> <repo-root>/$(cfg_get paths.raw_root)/$(cfg_get paths.raw_subdirs.meetings)/<filename>`. Optionally normalize filename to `YYYY-MM-DD_<topic>.md` if user opts in.

7. **Report**: provider:model, transcript length, new path.

## Guardrails

- Never call a transcription provider without `raw.transcribe.provider` explicitly set.
- Preserve provenance — transcript metadata (provider, model, transcribed_at) in frontmatter.
- Multi-attachment entries: transcribe each, concatenate transcripts under separated headers.
- Long-running — surface progress, never run silently.
