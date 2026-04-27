---
name: raw-ingest-github
description: Pull issues and comments from external GitHub repos we collaborate on (not the current repo) into the raw inbox via gh CLI. Repos come from raw.github.repos. Standalone-invokable; also wrapped by /dd:raw:ingest-github.
---

You are the raw-ingest-github skill. Bulk-ingest GitHub issues and comments from upstream / partner / collaborator repos. The current repo is never targeted — its own issues are first-class via `/dd:plan:*`.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **Tool check**: `gh auth status` must succeed. Absent → `ERROR: gh CLI not authenticated. Run gh auth login then re-run.` Exit non-zero.

2. **Read config**:
   ```bash
   repos="$(cfg_array_get raw.github.repos)"
   since_days="$(cfg_get raw.github.since_days)"   # default 7
   ```
   Empty `repos` → abort: "raw.github.repos must be configured."

3. **For each `<owner>/<repo>`**: pull issues updated since `<now> - since_days` via `gh issue list --json number,title,body,state,createdAt,updatedAt,author,labels,url,comments`. Watermark per-repo in `<repo>/.drydock/state/github-<owner>-<repo>.json`.

4. **For each issue**:
   - `dedup_key`: `github:<owner>/<repo>#<num>`.
   - **Existing file** → merge new comments under `--- updated at <captured_at> ---`, union parties, advance `captured_at`.
   - **New** → create file. Filename: `${created_at:0:10}_github_${owner}-${repo}-${num}_$(fm_slug "${title}").md`.
   - Frontmatter: `source: github`, `captured_at`, `dedup_key`, `original_at: <updatedAt>`, `parties: [author, commenters]`, `links: [issue URL]`, `topics: [labels]`, `proposed_category: client-boards`, `github.{repo, number, state, author}`, `traces_to: {}`.
   - Body: title; issue body; comments section with author and date.
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "github"}`.

5. **Report**: ingested, updates merged, skipped, errors.

## Guardrails

- Repo list from `raw.github.repos` only; never target the current repo.
- Dedup by `<owner>/<repo>#<num>`; comments-only updates merge into existing.
- Watermark per-repo; advance only on success.
