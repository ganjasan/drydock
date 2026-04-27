---
description: Promote a triaged GitHub issue to an OpenSpec change in the right target repo
argument-hint: "<issue-ref>"
allowed-tools: Bash, Read, SlashCommand
---

Take a triaged backlog issue and create an OpenSpec change in the target repo. Load Drydock config and helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh";       dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/area_routing.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/gh_project.sh"
```

By default the target is the current repo; if any layer declares an `area_to_repo` mapping, the issue's Area field can route the change to a different repo via `dd_resolve_area`.

## Procedure

### 1. Resolve issue

`gh issue view <ref> --json number,title,body,labels,projectItems` — fetch metadata.

### 2. Preflight

Reject and ask the user to run `/dd:plan:triage` first if any of the following:
- The configured triage label is still present (`cfg_get github.triage_label`, default `status/needs-triage`).
- A configured project's required fields (Area, Priority, Phase) are unset.
- The issue is labelled `type/epic` — epics stay where they are; their sub-issues get promoted.

### 3. Resolve target repo

Call `dd_resolve_area <area>`:

- **Returns absolute path on success** — that's the target repo.
- **Returns non-zero with fail-loud diagnostic** when `area_to_repo` is set but the area has no mapping. The diagnostic includes a copy-pasteable mapping snippet and lists known mappings. The command must propagate this failure: print the diagnostic, refuse to promote, and offer to add `<area>: <path>` to `<repo>/.drydock/config.yaml`.
- **Returns the current repo** when `area_to_repo` is unset entirely OR when the value is `.`.

The `dd_resolve_area` helper handles all five edge cases (unset, missing mapping, `.`, absolute path, relative path resolved to parent of current repo) — the command never re-implements them.

### 4. Navigate

`cd <target-repo-path>`. Verify clean main branch; otherwise warn and ask.

### 5. Sanity-check the target repo

- Has an `openspec/` directory? If not, fail with a clear error.

### 6. Create the change

Invoke `/opsx:new` with a name derived from the issue title (sanitized via `lib/frontmatter.sh::fm_slug`).

Add to the change's `.openspec.yaml` frontmatter:

```yaml
linked_issue: "<owner>/<repo>#<N>"
hub_parent: "<owner>/<repo>#<parent-N>"   # if a parent epic exists
area: <area>                              # if applicable
phase: <phase>                            # if applicable
priority: <priority>                      # if applicable
```

### 7. Copy context into proposal.md

Append (or seed) a "Context" section in the change's `proposal.md`:
- Issue title and body.
- Parent epic summary (if linked).
- Related ADR / requirements file references parsed from the body.

### 8. Update the issue

- Comment on the issue: `Promoted to OpenSpec change: <target-repo>/openspec/changes/<change-slug>/`.
- If a project is configured, set Status → `Ready` via `dd_project_field_set <item-id> status ready`. The helper no-ops silently when fields are unconfigured.

### 9. Report

```
Promoted <owner>/<repo>#<N>
├ Target repo:     <target-repo>
├ OpenSpec change: <change-slug>
├ Parent epic:     <owner>/<repo>#<parent>   (if applicable)
└ Next:           /dd:build:start  or  /opsx:continue
```

## Guardrails

- **Triage is a hard prerequisite**: never promote an issue still carrying the triage label.
- **Fail loudly on missing area mapping**: do not silently fall back to the current repo when `area_to_repo` exists but lacks an entry — that is the surfacing gap users want to see.
- Never modify the issue body — only add a comment and update Status.
- Never create an `openspec/` directory in a repo that does not already use OpenSpec.
