---
name: raw-capture
description: Capture an external signal (meeting note, email, idea, client request) into <repo>/<paths.raw_root>/_incoming/ with structured frontmatter. Universal — sources and filters come from <repo>/.drydock/config.yaml. Standalone-invokable; also wrapped by /dd:raw:capture.
---

You are the raw-capture skill. Your job is to take user-provided content (typed or from a file path) and write it as a Drydock raw inbox entry with the universal frontmatter schema documented in `docs/extension-model.md` § raw.

## Setup

Load merged Drydock config and helpers (paths come from caller's CWD):

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"

raw_root="$(cfg_get paths.raw_root)"
incoming_subdir="$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${raw_root}/${incoming_subdir}"
```

## Procedure

### 1. Gather content

The user either:
- Pastes content directly in conversation (primary mode), OR
- Provides a file path (read it).

If neither — ask what to capture. Do not invent content.

### 2. Identify metadata

Ask only for fields not inferrable from content:

- **source**: `manual` unless URL/headers reveal `gmail`, `calendar`, `drive`, `notion`, `linear`, or `github`.
- **captured_at**: now in ISO 8601 UTC.
- **parties**: people/emails mentioned.
- **links**: URLs in content.
- **attachments**: referenced files (e.g. `drive:<file-id>`).
- **topics**: 2–5 short lowercase tags.
- **proposed_category**: from `cfg_array_get raw.classifier.categories` — defaults: meetings, feedback, ideas, competitors, client-boards. Leave blank if ambiguous.

### 3. Compute dedup_key

Per-source schemes:

- `manual` → `manual:<sha256-of-body>` (use `fm_content_hash`)
- `gmail` → `gmail:<message-id>`
- `calendar` → `calendar:<event-id>`
- `drive` → `drive:<file-id>`
- `notion` → `notion:<page-id>`
- `linear` → `linear:<issue-identifier>`
- `github` → `github:<owner>/<repo>#<num>`

### 4. Dedup check

Search the entire raw root for the same `dedup_key`. If found, do not duplicate — append the new content to the existing file's body under `--- captured again at <captured_at> ---`, union frontmatter `parties`/`links`/`attachments`, report.

### 5. Filename and write

```
${target_dir}/${captured_at:0:10}_${source}_$(fm_slug "${title}").md
```

Frontmatter required keys: `source`, `captured_at`, `dedup_key`. Optional: `parties`, `links`, `attachments`, `topics`, `proposed_category`, `traces_to`, `original_at`, plus a `captured_by: claude-code:raw-capture` line for provenance.

Body: original content, lightly cleaned (HTML→md, strip tracking pixels and signature boilerplate). **Never summarise or paraphrase** — preserve verbatim.

### 6. Post-capture lifecycle hook

```bash
extra=$(jq -cn --arg item "${raw_root}/${incoming_subdir}/${filename}" --arg src "${source}" \
        '{item_path: $item, source: $src}')
dd_hook_invoke post-capture "$extra"
```

`post-capture` warns on non-zero, does not roll back.

### 7. Report

Under 8 lines: filename, source, dedup_key, proposed category, next-step suggestion (`/dd:raw:process`).

## Guardrails

- Verbatim body preservation; no paraphrasing.
- Refuse if content contains apparent secrets — recommend redaction.
- Never invent metadata; leave fields empty when unknown.
- No project-specific category lists or filters in this skill — all such values via `cfg_*` helpers.
