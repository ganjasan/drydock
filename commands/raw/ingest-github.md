---
description: Pull issues and comments from external GitHub repos we collaborate on (not the current repo) into the raw inbox
allowed-tools: Bash, Read, Write
---

Bulk-ingest GitHub issues and comments from upstream / partner / collaborator repos via `gh` CLI. Targets come from `raw.github.repos`. The current repo is **not** included — its own issues are managed by `/dd:plan:*` not by raw ingestion.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. Tool check

`gh` CLI must be authenticated (`gh auth status`). If not, fail with: `ERROR: gh CLI not authenticated. Run gh auth login then re-run.` Exit non-zero. (No MCP — this command uses `gh` directly because GitHub access is universally available where Drydock is used.)

### 2. Read filter config

```bash
repos="$(cfg_array_get raw.github.repos)"        # list of <owner>/<repo>
since_days="$(cfg_get raw.github.since_days)"    # default 7
```

If `repos` is empty, abort: "raw.github.repos must be configured."

### 3. Pull issues and comments

For each `<owner>/<repo>`:

```bash
since=$(date -u -d "${since_days} days ago" +%Y-%m-%dT%H:%M:%SZ)
gh issue list -R "$repo" --state all --limit 200 \
  --json number,title,body,state,createdAt,updatedAt,author,labels,url,comments \
  | jq --arg since "$since" '[.[] | select(.updatedAt > $since)]'
```

For each matching issue, also pull comments updated since the watermark.

### 4. For each issue — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

a. **`dedup_key`**: `github:<owner>/<repo>#<num>`.

b. **Dedup**: existing file → merge new comments under `--- updated at <captured_at> ---` separator, union parties, advance the file's `captured_at`. Otherwise create new.

c. **Filename**: `${created_at:0:10}_github_${owner}-${repo}-${num}_$(fm_slug "${title}").md`.

d. **Frontmatter**:

```yaml
---
source: github
captured_at: <ISO 8601 UTC, now>
dedup_key: github:<owner>/<repo>#<num>
captured_by: claude-code:/dd:raw:ingest-github
original_at: <issue updatedAt>
parties: [<author-login>, <commenter-logins>]
links: [<issue URL>]
attachments: []
topics: [<labels>]
proposed_category: client-boards
github:
  repo: <owner>/<repo>
  number: <int>
  state: <open|closed>
  author: <login>
traces_to: {}
---

# <title>

<issue body as markdown>

## Comments

- <author> @ <date>: <comment body>
...
```

e. **Post-capture hook** per item.

### 5. Report

```
Ingested <N> issue(s) across <R> repo(s); <U> updates merged; skipped <M> unchanged
```

## Guardrails

- Repo list comes only from `raw.github.repos` config; never include the current repo here (the current repo's issues are first-class via `/dd:plan:*`).
- Dedup by `<owner>/<repo>#<num>`; comments merge into existing.
- Watermark per-repo; failures should not advance it.
