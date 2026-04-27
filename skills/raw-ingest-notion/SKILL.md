---
name: raw-ingest-notion
description: Pull Notion pages from configured databases into the raw inbox via the Notion MCP. Databases come from raw.notion.databases — list of {id, label}. Standalone-invokable; also wrapped by /dd:raw:ingest-notion.
---

You are the raw-ingest-notion skill. Bulk-ingest Notion pages as raw items.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **MCP detection**: Notion MCP must be connected. Absent → fail.

2. **Read database list**:
   ```bash
   db_count=$(jq '.raw.notion.databases | length // 0' "$DRYDOCK_CONFIG_PATH")
   ```
   Empty list → abort: "raw.notion.databases must be configured (list of {id, label})."

3. **Maintain a per-database watermark** in `<repo>/.drydock/state/notion-<db-id>.json` (last synced `updated_at`). Pull pages updated since the watermark; advance the watermark only on successful pull.

4. **For each page**:
   - `dedup_key`: `notion:<page-id>`. Skip if exists. (Optionally: replace if `updated_at` newer — opt-in.)
   - Filename: `${updated_at:0:10}_notion_$(fm_slug "${title}").md`.
   - Frontmatter: `source: notion`, `captured_at`, `dedup_key`, `original_at: <updated_at>`, `parties: [authors, mentioned users]`, `links: [page URL, body URLs]`, `notion.{page_id, database_id, database_label, properties}`, `traces_to: {}`.
   - Body: page content as markdown.
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "notion"}`.

5. **Report**: ingested across N databases, skipped, errors.

## Guardrails

- Database IDs from `raw.notion.databases` only.
- Database label is informational; never use for routing.
- Watermark advances only on success; failures must not skip pages on next run.
- Dedup by stable page-id.
