---
description: Pull Gmail messages matching configured filters into the raw inbox (requires authenticated Gmail MCP)
allowed-tools: Bash, Read, Write
---

Bulk-ingest Gmail messages into the raw inbox via the Gmail MCP server. Filters and look-back window come from `<repo>/.drydock/config.yaml` under `raw.gmail.*`. Universal — no client filters in this command file.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. MCP detection

Verify the Gmail MCP server is connected (probe via `/mcp list` or equivalent introspection). If absent:

```
ERROR: Gmail MCP is not connected.
Install/authenticate Gmail MCP first, then re-run /dd:raw:ingest-gmail.
```

Exit non-zero. Do not proceed.

### 2. Read filter config

```bash
query="$(cfg_get raw.gmail.query)"           # e.g. "is:unread label:work"
labels="$(cfg_array_get raw.gmail.labels_to_track)"
since_days="$(cfg_get raw.gmail.since_days)"  # default: 7 if unset
```

If `query` is empty and `labels` is empty, abort with: "raw.gmail.query or raw.gmail.labels_to_track must be configured. See docs/extension-model.md § raw."

Combine: effective query = `query` AND any `label:<name>` from labels AND `newer_than:${since_days}d`.

### 3. Pull messages

Call the Gmail MCP `search_messages` (or equivalent) with the effective query. Fetch full content for each match.

### 4. For each message — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

For each message:

a. **`dedup_key`**: `gmail:<message-id>` (extract from `Message-ID:` header; canonical form, lowercase).

b. **Dedup check**: skip if `grep -rl "^dedup_key: ${dedup_key}$" "<repo-root>/${raw_root}/"` finds a match.

c. **Filename**: `${date_iso:0:10}_gmail_$(fm_slug "${subject}").md`.

d. **Body cleanup**: HTML→markdown, strip tracking pixels and signature boilerplate. Preserve original verbatim otherwise.

e. **Write file** to `${target_dir}/${filename}` with frontmatter:

```yaml
---
source: gmail
captured_at: <ISO 8601 UTC, now>
dedup_key: gmail:<message-id>
captured_by: claude-code:/dd:raw:ingest-gmail
original_at: <message Date header in ISO 8601>
parties: [<from-email>, <to-emails...>]
links: [<urls extracted from body>]
attachments: [<attachment paths if any>]
topics: []
proposed_category: ""
gmail:
  thread_id: <thread-id>
  labels: [<gmail labels>]
traces_to: {}
---

# <subject>

<message body, HTML→markdown>
```

f. **Post-capture hook** per item:

```bash
extra=$(jq -cn --arg item "${incoming}/${filename}" --arg src gmail \
        '{item_path: $item, source: $src}')
dd_hook_invoke post-capture "$extra"
```

### 5. Final report

```
Ingested <N> Gmail message(s); skipped <M> existing (dedup); <K> errors
Run /dd:raw:process to classify the inbox.
```

## Guardrails

- Filter set comes only from `raw.gmail.*` config — never hardcode queries or labels here.
- If MCP is absent, fail loudly with install guidance; never silently degrade.
- Skip duplicates by `dedup_key` (message-id); never overwrite existing items.
- Preserve message bodies verbatim post-cleanup; do not summarise.
