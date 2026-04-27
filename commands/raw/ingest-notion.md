---
description: Pull Notion pages from configured databases into the raw inbox (requires authenticated Notion MCP)
allowed-tools: Bash, Read, Write
---

Bulk-ingest Notion pages as raw items via the Notion MCP. Databases come from `raw.notion.databases` — a list of `{id, label}` objects.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. MCP detection

Verify Notion MCP is connected. If absent: `ERROR: Notion MCP is not connected.` Exit non-zero.

### 2. Read database list

```bash
# raw.notion.databases is an array of {id, label} objects
database_count=$(jq '.raw.notion.databases | length // 0' "$DRYDOCK_CONFIG_PATH")
```

If empty, abort: "raw.notion.databases must be configured (list of {id, label})."

### 3. Pull pages

For each `{id, label}` entry, call Notion MCP to list pages updated since last run (or last `since_days` if no state file). For each page, fetch full content as markdown.

State file: `<repo>/.drydock/state/notion-<db-id>.json` storing the last synced `updated_at` per database. Update after each successful pull.

### 4. For each page — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

a. **`dedup_key`**: `notion:<page-id>`.

b. **Dedup**: skip if exists. (For dedup-on-update behavior, optionally re-fetch and replace if `updated_at` is newer — up to the user; default skip.)

c. **Filename**: `${updated_at:0:10}_notion_$(fm_slug "${title}").md`.

d. **Frontmatter**:

```yaml
---
source: notion
captured_at: <ISO 8601 UTC, now>
dedup_key: notion:<page-id>
captured_by: claude-code:/dd:raw:ingest-notion
original_at: <page updated_at in ISO 8601>
parties: [<page authors / mentioned users>]
links: [<page URL>, <urls in body>]
attachments: []
topics: []
proposed_category: ""
notion:
  page_id: <id>
  database_id: <id>
  database_label: <label from config>
  properties: <key page properties — title, status, owner, …>
traces_to: {}
---

# <title>

<page content as markdown>
```

e. **Post-capture hook** per item.

### 5. Report

```
Ingested <N> Notion page(s) across <D> database(s); skipped <M> existing
```

## Guardrails

- Database IDs come only from `raw.notion.databases` config.
- Dedup by stable page-id.
- Database label is informational — never rely on it for routing logic.
- Update state file only on successful pull; failures should not advance the watermark.
