---
name: raw-process
description: Process the raw inbox — classify items via the raw-classifier subagent, dedup by dedup_key, cross-link to existing requirements/issues, and propose backlog items. Standalone-invokable; also wrapped by /dd:raw:process.
---

You are the raw-process skill. Your job is to walk through every file in the raw inbox and either move it to the correct classified subdirectory, merge it into an existing item (dedup), or flag it for review. Optionally propose backlog items for clearly actionable content.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"

raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

## Procedure

1. **Empty-inbox short-circuit**: if `${target_dir}` is missing or has no `*.md` files → report empty, exit 0.

2. **Validate frontmatter** for each file: `fm_require <file> source captured_at dedup_key`. Files missing required keys land in "needs human attention"; not classified this run.

3. **Spawn the `dd:raw-classifier` subagent** with validated paths. Agent returns one decision per file: category, confidence, reason, suggested_filename, entities, dedup_candidates, actionable, proposed_issue.

4. **Dedup pass — merge same-`dedup_key` items**:
   - Frontmatter union: `parties`, `links`, `attachments`, `traces_to.*`. Earliest `original_at` and `captured_at` win.
   - Body: concatenate with `--- duplicate captured at <captured_at> ---` separator.
   - When `--strict` is passed and bodies differ materially, refuse merge for that group; flag.

5. **Cross-link** each classified item against `<repo>/<paths.requirements>/use-cases/UC-*.md`, `<repo>/<paths.requirements>/adr/*.md`, and open GitHub issues (`gh issue list --state open --limit 200`). Add matches to `traces_to.{use_cases, adrs, issues}`.

6. **Build preview**: one line per item showing proposed move, traces_to additions, and dedup partner if any. Then a "Backlog suggestions" section with proposed `gh issue create` invocations for `actionable: true` items.

7. **Confirmation gate**: interactive → require user confirmation; `--apply` flag skips it. Decline → exit 0 with no changes.

8. **Apply moves**: `git mv` (preserves history) per item. Update frontmatter on the moved file with merged `traces_to`. Per-item failures log and continue; do not abort the whole batch.

9. **Cross-link write-back**: for each cross-link, update the referenced artifact's `related:` or `traces_to.raw:` to back-link bidirectionally.

10. **Backlog suggestions**: present the proposed `gh issue create` invocations but **do not execute** — explicit human-in-the-loop guard.

11. **Final report**: counts per category, dedup count, flagged-for-review count, backlog suggestion count, skipped-validation count.

## Guardrails

- Never auto-create GitHub issues; user runs `gh issue create` themselves.
- Use `git mv` to preserve history when possible.
- Never delete content; merges concatenate, classification moves preserve.
- Do not call external LLM APIs on private content (frontmatter `sensitivity: client-private`); classification is heuristic + Claude session context only.
- Per-item failures must not abort the whole run.
- Categories come from `cfg_array_get raw.classifier.categories`; respect custom sets.
