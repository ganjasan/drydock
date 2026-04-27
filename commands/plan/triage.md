---
description: Triage GitHub issues labeled with the configured needs-triage label — set Priority/Area/Phase/Parent interactively
allowed-tools: Bash, Read, SlashCommand
---

Walk through every issue carrying the configured triage label (default `status/needs-triage`). For each, ask the user short, focused questions to fill the missing fields and link a parent epic. **Do not batch-auto-decide** — this is a human-in-the-loop tool.

## Procedure

Read `${CLAUDE_PLUGIN_ROOT}/config.yaml` for `github.triage_label`, project field definitions, and any list of repos to scan. Without configuration, scan only the current repo.

### 1. List candidates

```
gh issue list -R <owner>/<repo> \
  --label "<config.github.triage_label>" \
  --state open \
  --json number,title,url,labels,projectItems
```

If `config.yaml` declares additional repos to triage across, iterate over them in priority order.

Announce the count: "N issues to triage."

### 2. Per-issue prompt loop

For each issue, show:
- Title + URL.
- First ~15 lines of the body.
- Current labels.
- Current project field values (likely empty for fields the user hasn't set).

Then ask the user to fill missing fields (skip any already set):

1. **Priority** — value from `github.project_fields.priority.options`, if configured. Default: `P0`/`P1`/`P2`/`P3`.
2. **Area** — value from `github.project_fields.area.options`, if configured.
3. **Phase** — value from `github.project_fields.phase.options`, if configured. Otherwise skip.
4. **Size** — XS/S/M/L/XL (optional).
5. **Parent epic** — pick one from a list of open `type/epic` issues; offer match by Area if obvious.

### 3. Apply updates

Use `gh project item-edit` with field IDs from `config.yaml` to set Priority/Area/Phase/Size.

If a project is configured, set Status to `Backlog` (or `Ready` if the user confirms readiness).

If a parent was chosen, link as a sub-issue via the `addSubIssue` GraphQL mutation.

Remove the triage label; keep priority labels (e.g. `priority/P1`) consistent with the project-field value if both layers are used.

### 4. Per-issue summary line

```
#42 <title>    →   P1 · <area> · <phase> · parent <owner>/<repo>#<N>
```

### 5. Final report

```
Triaged N issues
├ Priority breakdown:  P0:0 P1:3 P2:5 P3:2
├ Phase breakdown:     <if configured>
├ Areas touched:       <if configured>
└ Parents assigned:    <repo>#<E>(K) ...

Skipped: 0
Needs human thought later: 0
```

## Guardrails

- Never change a label or project field without per-issue user confirmation.
- Never edit issue body or comments.
- If no project is configured, set labels only (`priority/<P>` etc.) and skip the project-field calls.
- If an issue lacks a clear owner and no clear parent, leave the triage label on it and flag it in the final summary.
