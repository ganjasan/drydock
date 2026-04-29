---
description: Show current position in the Drydock workflow — repo, branch, worktree, active OpenSpec change, open PRs, and (if configured) project board snapshot
allowed-tools: Bash, Read, Glob, Grep
---

Report a concise status of where the user is in the Drydock workflow, using only generic git, `gh`, and filesystem checks. Optional sections appear only when their inputs are configured.

## Procedure

Load merged Drydock configuration via `source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load`. The loader merges three layers in order (later wins): plugin-root defaults → `~/.drydock/config.yaml` (optional) → `<repo>/.drydock/config.yaml`. Read keys via `cfg_get <dotted.key>`, `cfg_has <dotted.key>`, `cfg_array_get <dotted.key>`, or `cfg_keys_of <dotted.key>`. If no config layer declares a GitHub Project, all project-related sections are skipped silently.

Collect and print, in this order:

### 1. Location

- Current working directory.
- Current git branch: `git rev-parse --abbrev-ref HEAD`.
- One-line summary of `git status -s` (count of uncommitted changes).
- Whether the checkout is a worktree (`git rev-parse --git-common-dir` differs from `--git-dir`).

### 2. Active work artifacts

- **OpenSpec change**: scan `openspec/changes/<slug>/` for any directory whose `.openspec.yaml` does **not** contain `status: done`. Show the change slug and which artifacts (`proposal.md`, `design.md`, `tasks.md`, `specs/`) exist; for `tasks.md`, also show count of completed (`- [x]`) vs. total (`- [x]` + `- [ ]`) items.
- **Linked issue**: if the active change frontmatter includes a `linked_issue` key, OR the branch matches `feature/<N>-*`, fetch that issue via `gh issue view <N> --json number,title,state,labels,url` and show one line.
- **Open PRs by user**: `gh pr list --author @me --state open --json number,title,url` for the current repo. List each on one line.

### 2a. Active feature flow (only if in flow)

Source the helper and probe phase position:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/feature_state.sh"
phase="$(dd_feature_position)"
```

If `${phase}` is anything other than `none`, print one line:

```
┃   Active feature flow: <label>
```

Where `<label>` comes from `dd_feature_label "${phase}"` — e.g. `phase 6 — architect draft ready for review`. If `${phase}` is `none`, omit this line.

This signal supplements the OpenSpec change line above; the change reports artifact existence, the feature-flow line reports where the orchestrator would resume.

### 3. Raw inbox (only if a raw root exists)

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming_subdir="$(cfg_get paths.raw_subdirs.incoming)"
inbox_dir="<repo-root>/${raw_root}/${incoming_subdir}"
```

If `${inbox_dir}` does not exist AND no `raw.*` config is declared, omit this section. Otherwise report the count of `*.md` files in `_incoming/` and (if available) the timestamp of the most recent classified item under `${raw_root}/<other-subdir>/` (proxy for "last `/dd:raw:process` invocation").

```
┃   Raw inbox:    12 in _incoming · last process: 4 days ago
```

If the inbox is empty: `┃   Raw inbox:    — clean`.

### 4. Project snapshot (only if configured)

If `cfg_has github.project.number` returns true:

- Use `cfg_get github.project.number` and `cfg_get github.org` (or derive org from `gh repo view`) to call `gh project item-list <number> --owner <org> --format json` and count items by Status field.
- If the call rate-limits or fails, print "— skipped (rate limit or missing project scope)".

If `github.project` is not configured in any layer, omit this section entirely.

## Output format

Keep output under ~30 lines. One section per cluster above. Use box-drawing prefixes. If a section has nothing to report, write "— clean" or "— none".

Example shape (with project configured):

```
┣ Location
┃   cwd:    /path/to/my-repo
┃   branch: feature/42-add-dark-mode  (2 uncommitted)
┃   worktree: yes (.worktrees/wt-42)
┣ Active work
┃   OpenSpec change: add-dark-mode  (proposal ✓, design ✓, tasks 3/7)
┃   Linked issue:    my-org/my-repo#42  (open)
┃   Open PRs:        my-org/my-repo#11 (draft)
┣ Raw inbox
┃   12 in _incoming · last process: 4 days ago
┣ Project
┃   18 items: 12 Backlog · 4 In progress · 2 In review · 0 Done
```

Example shape (no config):

```
┣ Location
┃   cwd:    /path/to/my-repo
┃   branch: main  (clean)
┃   worktree: no
┣ Active work
┃   OpenSpec change: — none
┃   Linked issue:    — none
┃   Open PRs:        — none
```

After printing, suggest running `/dd:next` for an actionable next step.

## Guardrails

- Never assume any specific GitHub org, project number, or directory layout beyond the current repo.
- Do not call `gh project` when no project is configured — that requires a scope (`read:project`) the user may not have granted.
- Read-only operation; never modify files or git state.
