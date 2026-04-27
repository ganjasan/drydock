---
description: Capture a new backlog item — creates a GitHub issue with sensible defaults
argument-hint: "[<type: feature | bug | task>] [<title>]"
allowed-tools: Bash, Read, SlashCommand
---

Create a GitHub issue and (optionally) add it to a configured GitHub Project. Works whether or not a project is configured: with no project, the command files an issue at the repo level with the right labels.

## Procedure

Read `${CLAUDE_PLUGIN_ROOT}/config.yaml` for `github.project`, `github.project_fields`, `github.triage_label`, and any custom label sets. If no `config.yaml`, use built-in defaults.

### 1. Parse arguments

- First token in `$ARGUMENTS` interpreted as `type` (`feature`, `bug`, `task`). If absent, ask.
- Remaining tokens form the issue title. If absent, ask.

### 2. Determine repo

Default: the current `gh repo view --json nameWithOwner` repo. If the user wants to file the issue elsewhere, accept an `--repo <owner>/<repo>` override.

### 3. Gather optional fields

If a project is configured, ask (only fields you don't already have):
- **Area** — value from `github.project_fields.area.options` keys, if defined.
- **Priority** — `P0`/`P1`/`P2`/`P3` (or whatever `github.project_fields.priority.options` declares).
- **Phase** — if `github.project_fields.phase` is configured.
- **Parent epic** — optional, links as a sub-issue.
- **Body** — brief description (or invoke a repo-level issue template).

If no project is configured, only ask for:
- **Body** (or fall through to issue template).
- **Labels** if the repo has a label set the user wants applied.

### 4. Create the issue

```
gh issue create \
  --title "<title>" \
  --label "type/<X>"<,priority/<PN>><,status/needs-triage> \
  --body "<body>"
```

Apply `<config.github.triage_label>` (default `status/needs-triage`) if any required project field is missing — otherwise skip the triage label.

### 5. Project board (only if configured)

If `config.yaml` declares `github.project.id`:
- The Action `add-to-project` may pick the issue up automatically.
- Set explicit project fields via `gh project item-edit` using the field IDs from `github.project_fields.*`.

If no project is configured: skip — the issue lives at the repo level only.

### 6. Sub-issue linkage (optional)

If the user named a parent epic, link via the GraphQL `addSubIssue` mutation.

### 7. Report

```
Created <owner>/<repo>#<N>
├ Type:     <feature|bug|task>
├ Area:     <area>      (if applicable)
├ Priority: <P>          (if applicable)
├ Phase:    <phase>      (if applicable)
├ Parent:   <owner>/<repo>#<parent>   (if applicable)
└ URL:      <URL>
```

## Guardrails

- Never invent a project number. If `config.yaml` does not declare a project, do not call `gh project`.
- Never apply project field values that are not in the configured options table.
- Triage label is configurable; default is `status/needs-triage`.
