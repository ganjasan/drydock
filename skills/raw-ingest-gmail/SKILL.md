---
name: raw-ingest-gmail
description: Pull Gmail messages matching configured filters into the raw inbox via the Gmail MCP. Filters and look-back window come from raw.gmail.* config. Universal — no client-specific filters. Standalone-invokable; also wrapped by /dd:raw:ingest-gmail.
---

You are the raw-ingest-gmail skill. Bulk-ingest Gmail messages into the Drydock raw inbox via the Gmail MCP server.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"

raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

## Procedure

1. **MCP detection**: verify Gmail MCP is connected. Absent → `ERROR: Gmail MCP is not connected. Install/authenticate, then re-run.` Exit non-zero.

2. **Read filter config**:
   ```bash
   query="$(cfg_get raw.gmail.query)"
   labels="$(cfg_array_get raw.gmail.labels_to_track)"
   since_days="$(cfg_get raw.gmail.since_days)"
   ```
   Empty `query` AND empty `labels` → abort: "raw.gmail.query or raw.gmail.labels_to_track must be configured."
   Effective query = `query` AND any `label:<n>` from labels AND `newer_than:${since_days}d`.

3. **Pull messages** via Gmail MCP `search_messages` with the effective query.

4. **For each message**:
   - `dedup_key`: `gmail:<message-id>`. Skip if exists anywhere under raw_root.
   - Filename: `${date_iso:0:10}_gmail_$(fm_slug "${subject}").md`.
   - Body cleanup: HTML→markdown, strip tracking pixels and signature boilerplate; preserve verbatim otherwise.
   - Frontmatter required: `source: gmail`, `captured_at`, `dedup_key`. Optional `original_at` (Date header), `parties` (from + to), `links`, `attachments`, `gmail.{thread_id, labels}`, `traces_to: {}`.
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "gmail"}`.

5. **Report**: ingested count, skipped (dedup) count, errors. Suggest `/dd:raw:process` next.

## Guardrails

- Filter set comes only from `raw.gmail.*` config; never hardcode queries or labels.
- MCP absent → fail loudly; never silently degrade.
- Skip duplicates by `dedup_key`; never overwrite.
- Verbatim preservation post-cleanup.
