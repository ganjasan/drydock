---
description: Capture an external signal (meeting note, email, idea, client request) into <repo>/<paths.raw_root>/_incoming/ with structured frontmatter
argument-hint: "[<category>] [<file-path>]"
allowed-tools: Bash, Read, Write, Edit
---

Capture raw content into the Drydock raw inbox. Universal — sources and filters come from `<repo>/.drydock/config.yaml`; nothing in this command file is project-specific.

## Procedure

Load merged Drydock config and the hook dispatcher:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"

raw_root="$(cfg_get paths.raw_root)"
incoming_subdir="$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${raw_root}/${incoming_subdir}"
```

### 1. Gather content

The user either:
- Pastes content directly in the conversation turn (primary mode), OR
- Provides a file path via `$ARGUMENTS` (read it).

If neither — ask what to capture. Do not invent content.

### 2. Identify metadata

Ask only for fields that cannot be inferred from the content or `$ARGUMENTS`:

- **source**: `manual` unless URL/headers reveal the source (`gmail`, `calendar`, `drive`, `notion`, `linear`, `github`).
- **captured_at**: current UTC timestamp in ISO 8601.
- **parties**: people mentioned by name or email in the content.
- **links**: URLs referenced in the content.
- **attachments**: file paths if any (e.g. a Drive recording referenced in a meeting note).
- **topics**: 2–5 short lowercase tags.
- **proposed_category**: one of the categories from `cfg_array_get raw.classifier.categories` — defaults: `meetings`, `feedback`, `ideas`, `competitors`, `client-boards`. If ambiguous, leave blank for `/dd:raw:process` to decide.

### 3. Compute dedup_key

Per-source schemes (documented in `docs/extension-model.md`):

- `manual` → `manual:<sha256-of-body>`
- `gmail` → `gmail:<message-id>` (extract from headers if present)
- `calendar` → `calendar:<event-id>`
- `drive` → `drive:<file-id>`
- `notion` → `notion:<page-id>`
- `linear` → `linear:<issue-id>`
- `github` → `github:<owner>/<repo>#<num>`

Use `fm_content_hash` for the body-sha when needed (helper from `lib/frontmatter.sh`).

### 4. Dedup check

Before writing, search `${target_dir}` and the classified subdirectories for the same `dedup_key`:

```bash
matches=$(grep -rln "^dedup_key: ${dedup_key}$" "<repo-root>/${raw_root}/" 2>/dev/null || true)
```

If any match: do not write a duplicate. Instead, append the new content to the existing file's body under a `--- captured again at <captured_at> ---` separator, union frontmatter `parties` / `links` / `attachments`, and report to the user.

### 5. Filename

```bash
slug=$(fm_slug "<title or first-line of body>")
filename="${captured_at:0:10}_${source}_${slug}.md"
```

### 6. Write the file

Path: `${target_dir}/${filename}`

Frontmatter required keys per `extension-model` spec § raw:

```yaml
---
source: <source>
captured_at: <ISO 8601 UTC>
dedup_key: <per-source key>
captured_by: claude-code:/dd:raw:capture
parties: [...]
links: [...]
attachments: [...]
topics: [...]
proposed_category: <category-name or empty>
traces_to: {}        # populated by /dd:raw:process
---

# <title — extracted from content or user-provided>

<original content, lightly cleaned: strip tracking pixels, signature
boilerplate, HTML-to-markdown conversion. Do NOT summarise or paraphrase —
preserve verbatim.>
```

### 7. Post-capture lifecycle hook

Per item filed (so a single `/dd:raw:capture` invocation fires the hook exactly once):

```bash
extra=$(jq -cn --arg item "${raw_root}/${incoming_subdir}/${filename}" --arg src "${source}" \
        '{item_path: $item, source: $src}')
dd_hook_invoke post-capture "$extra"   # warns on non-zero, does not roll back
```

### 8. Report

```
Captured: ${raw_root}/${incoming_subdir}/${filename}
Source:   <source>
Dedup key: <key>
Category (proposed): <category or "—">
Next: /dd:raw:process  (when ready to classify the inbox)
```

## Guardrails

- Never modify the content body; preserve verbatim. Cleanup is limited to tracking pixels, signature boilerplate, and HTML→markdown conversion.
- If content appears to contain secrets (API keys, passwords, bearer tokens), refuse to write; surface the suspicion to the user and recommend they redact first.
- Never invent metadata — when a field cannot be inferred, leave it empty rather than guess.
- Never reach for project-specific category lists or filters in this command file. All such values come from `<repo>/.drydock/config.yaml` via `cfg_get`.
