---
description: Pull Linear issues and comments from configured teams into the raw inbox
allowed-tools: Bash, Read, Write
---

Bulk-ingest Linear issues into the raw inbox via the Linear MCP. Teams and filters come from `raw.linear.*` config.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. MCP detection

Verify Linear MCP is connected. If absent: `ERROR: Linear MCP is not connected.` Exit non-zero.

### 2. Read filter config

```bash
teams="$(cfg_array_get raw.linear.teams)"      # team IDs or keys
filter="$(cfg_get raw.linear.filter)"           # optional Linear filter expression
```

If `teams` is empty, abort: "raw.linear.teams must be configured."

### 3. Pull issues

For each team, call Linear MCP `list_issues` filtered by `filter` (if any) and updated since the last sync watermark (state file `<repo>/.drydock/state/linear-<team>.json`). Fetch issue body and recent comments.

### 4. For each issue — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

a. **`dedup_key`**: `linear:<issue-identifier>` (e.g. `linear:ENG-123`).

b. **Dedup**: skip if exists. For comment-only updates on an existing issue, append the new comments to the existing file's body under a `--- updated at <captured_at> ---` separator and union frontmatter.

c. **Filename**: `${created_at:0:10}_linear_${identifier}_$(fm_slug "${title}").md`.

d. **Frontmatter**:

```yaml
---
source: linear
captured_at: <ISO 8601 UTC, now>
dedup_key: linear:<identifier>
captured_by: claude-code:/dd:raw:ingest-linear
original_at: <issue updatedAt in ISO 8601>
parties: [<creator-email>, <assignee-email>, <commenter-emails>]
links: [<issue URL>, <urls in body and comments>]
attachments: [<attachment URLs>]
topics: [<labels from Linear>]
proposed_category: client-boards
linear:
  team: <team key>
  identifier: <ENG-123>
  status: <state name>
  priority: <p>
  assignee: <email>
traces_to: {}
---

# <identifier> · <title>

<issue description as markdown>

## Comments

- <author> @ <date>: <comment text>
...
```

e. **Post-capture hook** per item.

### 5. Report

```
Ingested <N> Linear issue(s) across <T> team(s); skipped <M> existing; <U> updates merged
```

## Guardrails

- Team IDs and filters come only from `raw.linear.*` config.
- Dedup by Linear identifier; comments-only updates merge rather than overwrite.
- Watermark is per-team; failures should not advance it.
