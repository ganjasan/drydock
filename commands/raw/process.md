---
description: Process the raw inbox — classify items, dedup, cross-link to existing requirements/issues, and propose backlog items
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

Walk through every file in the raw inbox and either move it to the correct classified subdirectory, merge it into an existing item (dedup), or flag it for review. Optionally propose backlog items for clearly actionable content.

## Procedure

Load merged Drydock config and frontmatter helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"

raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

### 1. Empty-inbox short-circuit

If `${target_dir}` does not exist or contains no `*.md` files, report "raw inbox is empty" and exit 0 without prompting.

### 2. Validate frontmatter

For each file in `${target_dir}/*.md` (skip files starting with `_`):

- `fm_require <file> source captured_at dedup_key` — required keys per `extension-model` spec § raw frontmatter.
- Files missing required keys are listed under "needs human attention" in the final report and are NOT classified in this run.

### 3. Spawn the raw-classifier agent

Invoke the `dd:raw-classifier` subagent with the list of validated paths. The agent returns one decision block per file (category, confidence, reason, suggested_filename, entities, dedup_candidates, actionable, proposed_issue). The agent is read-only — it does not move files.

### 4. Dedup pass — merge same-`dedup_key` items

Before classification moves, scan all incoming items and existing classified items for `dedup_key` collisions:

```bash
grep -rln '^dedup_key:' "<repo-root>/${raw_root}/" \
  | while read f; do
      key=$(awk '/^dedup_key:/{print $2; exit}' "$f")
      echo "$key|$f"
    done | sort | awk -F'|' 'count[$1]++'
```

For each collision group:

- **Frontmatter union**: union of `parties`, `links`, `attachments`, `traces_to.*`. Earliest `original_at` and earliest `captured_at` win.
- **Body**: concatenate with `--- duplicate captured at <captured_at> ---` separator.
- **Final location**: per the agent's `category` decision for the surviving item.
- **Inputs removed**: both source files removed from `_incoming/` (or wherever they were).

When `--strict` is passed and bodies differ materially, refuse to merge that group; flag in the report.

### 5. Cross-link to requirements and open issues

For each classified item (post-dedup):

- Search `<repo-root>/$(cfg_get paths.requirements)/use-cases/UC-*.md` for filename or content matches against the item's `parties`, key phrases, and `topics`. Add matches to `traces_to.use_cases`.
- Search `<repo-root>/$(cfg_get paths.requirements)/adr/*.md` similarly. Add to `traces_to.adrs`.
- Search open GitHub issues via `gh issue list --state open --json number,title,body --limit 200`. Add matching issue numbers to `traces_to.issues`.

Cross-links are advisory — false positives are acceptable because the user reviews the preview.

### 6. Build the preview

Print one line per item showing the proposed move:

```
- _incoming/<file>  →  <category-subdir>/<suggested-filename>
    traces_to: use_cases=[UC-005], issues=[#42]
    (dedup with: existing/path.md)        # only if applicable
- _incoming/<file>  →  _review/<file>     # if confidence too low
    reason: <agent's reason>
```

Then a "Backlog suggestions" section listing each `actionable: true` item with the proposed `gh issue create` invocation.

### 7. Confirmation gate

If interactive, ask the user to confirm before applying. If `--apply` is passed, skip confirmation. If the user declines, exit 0 without changes.

### 8. Apply moves

For each confirmed item:

- `git mv` (or `mv` if untracked) from `${target_dir}/<old>` to `<repo-root>/${raw_root}/<category-subdir>/<filename>`. Use `git mv` to preserve history when possible.
- Update the moved file's frontmatter with the merged `traces_to` and any normalized fields.
- For dedup merges, write the merged body and frontmatter to the surviving file; remove the duplicate.

If a per-item move fails, log it and continue with the next item — do not abort the whole batch.

### 9. Cross-link write-back

For each cross-link added:

- Update the referenced artifact's `related:` or `traces_to.raw:` frontmatter to back-link to the moved raw file. Bidirectional.

### 10. Backlog suggestions

For each `actionable: true` item, present the proposed `gh issue create` invocation but **do not execute** it — the user runs it manually after review. This is the explicit "human-in-the-loop" guard.

### 11. Final report

```
Processed N items from <raw_root>/<incoming_subdir>/
├ Moved to meetings/:       <count>
├ Moved to feedback/:       <count>
├ Moved to ideas/:          <count>
├ Moved to competitors/:    <count>
├ Moved to client-boards/:  <count>
├ Deduped (merged):         <count>
├ Flagged _review/:         <count>
└ Backlog suggestions:      <count>  (review and run gh issue create manually)

Skipped (frontmatter validation failed): <count>

Run `git status` to see the changes; commit when ready.
```

## Guardrails

- Never auto-create GitHub issues. The user reviews suggestions and runs `gh issue create` themselves.
- Preserve git history via `git mv`, not copy-then-delete, whenever possible.
- Never delete content; dedup merges concatenate, classification moves preserve.
- Never call external LLM APIs on content content explicitly marked as private (frontmatter `sensitivity` outside `public`); classification is heuristic + Claude session context only.
- Per-item failures must not abort the whole run; report and continue.
- The category set is governed by `cfg_array_get raw.classifier.categories` (defaults documented in the agent prompt). Custom categories are honored.
