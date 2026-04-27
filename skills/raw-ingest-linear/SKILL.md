---
name: raw-ingest-linear
description: Pull Linear issues and comments from configured teams into the raw inbox via the Linear MCP. Teams and filters come from raw.linear.* config. Standalone-invokable; also wrapped by /dd:raw:ingest-linear.
---

You are the raw-ingest-linear skill. Bulk-ingest Linear issues as raw items, with comments-only updates merged into existing entries.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **MCP detection**: Linear MCP must be connected. Absent → fail.

2. **Read config**:
   ```bash
   teams="$(cfg_array_get raw.linear.teams)"
   filter="$(cfg_get raw.linear.filter)"
   ```
   Empty `teams` → abort: "raw.linear.teams must be configured."

3. **Per-team watermark** in `<repo>/.drydock/state/linear-<team>.json`. Pull issues updated since watermark; advance only on success.

4. **For each issue**:
   - `dedup_key`: `linear:<identifier>` (e.g. `linear:ENG-123`).
   - **Existing file** → append new comments under `--- updated at <captured_at> ---`, union frontmatter parties/links, advance `captured_at`.
   - **New** → create file. Filename: `${created_at:0:10}_linear_${identifier}_$(fm_slug "${title}").md`.
   - Frontmatter: `source: linear`, `captured_at`, `dedup_key`, `original_at: <updatedAt>`, `parties: [creator, assignee, commenters]`, `links: [issue URL, body+comment URLs]`, `attachments`, `topics: [labels]`, `proposed_category: client-boards`, `linear.{team, identifier, status, priority, assignee}`, `traces_to: {}`.
   - Body: identifier · title; description; comments (with author and date).
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "linear"}`.

5. **Report**: ingested, updates merged, skipped, errors.

## Guardrails

- Team IDs / filters from `raw.linear.*` only.
- Comments-only updates merge, not overwrite.
- Watermark per-team; advance only on success.
