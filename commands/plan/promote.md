---
description: Promote a triaged GitHub issue to an OpenSpec change in the right target repo
argument-hint: "<issue-ref>"
allowed-tools: Bash, Read, SlashCommand
---

Take a triaged backlog issue and create an OpenSpec change in the target repo. By default the target is the current repo; if `config.yaml` declares an `area_to_repo` mapping, the issue's Area field can route the change to a different repo.

## Procedure

### 1. Resolve issue

`gh issue view <ref> --json number,title,body,labels,projectItems` — fetch metadata.

### 2. Preflight

Reject and ask the user to run `/dd:plan:triage` first if any of the following:
- The configured triage label is still present (`config.github.triage_label`, default `status/needs-triage`).
- A configured project's required fields (Area, Priority, Phase) are unset.
- The issue is labelled `type/epic` — epics stay where they are; their sub-issues get promoted.

### 3. Resolve target repo

If `config.yaml` declares `area_to_repo` AND the issue has an Area value:

- Look up `area_to_repo[<area>]`. If present, that's the target repo path (resolved relative to current repo's parent, or absolute).
- If the Area is set but has **no entry** in `area_to_repo` → fail loudly:
  - Print the missing mapping.
  - Offer to add `<area>: <path>` to `config.yaml`.
  - Refuse to promote until the mapping is supplied (or the user explicitly chooses the current repo).

If `area_to_repo` is not configured: target is the current repo (no implicit routing).

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
- If a project is configured, set Status → `Ready`.

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
