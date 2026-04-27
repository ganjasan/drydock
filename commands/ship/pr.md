---
description: Open a PR linking the active OpenSpec change and originating issue
allowed-tools: Bash, Read, SlashCommand
---

Open a pull request for the current branch. Links back to the active OpenSpec change and the originating GitHub issue. No GitHub Project assumption — works with or without `config.yaml`.

## Procedure

### 1. Preflight

- Current checkout has a non-`main` branch (else warn and offer to keep going).
- Working tree clean, all commits pushed to the remote branch (offer to push if not).
- Active OpenSpec change exists with all tasks checked. If `tasks.md` has unchecked items, refuse and suggest `/dd:build:code`.
- Tests are recently green (`/dd:build:test`). Offer to run if not recent.

### 2. Gather context

- Issue number from branch name (matching `feature/<N>-*`).
- Parent epic from the issue's project fields, if a project is configured.
- Active OpenSpec change slug and proposal summary.
- Commits on this branch since fork from `main`.

### 3. Generate PR description

Body template:

```markdown
<issue title — same as PR title>

Closes <owner>/<repo>#<issue-number>

## Summary
<One paragraph from openspec/changes/<slug>/proposal.md "Why" or "Summary" section.>

## Changes
<Bullet list of commit subjects on the branch, grouped by area if useful.>

## Test plan
- [ ] Unit tests pass locally
- [ ] Integration tests pass per repo conventions
- [ ] Manual smoke-test of <feature> on <environment>

## OpenSpec
- `openspec/changes/<slug>/` — see proposal, design, tasks, specs

## Related
- Parent epic: <owner>/<repo>#<parent-N>   <!-- only if a parent is linked -->
- ADRs / requirements referenced in proposal.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 4. Open the PR

```
gh pr create \
  --title "<issue title>" \
  --body "$(pr-body)" \
  --base main \
  --head <branch-name> \
  --draft
```

Default to **draft** — promotion to ready-for-review is a separate user step.

### 5. Linkage

- The `Closes <owner>/<repo>#<N>` line auto-creates the GitHub linkage.
- If a project is configured (`github.project.id` in `config.yaml`), set the issue's Status field to `In review`.
- Skip the project step silently if no project is configured.

### 6. Suggest review

- Offer to invoke the `code-reviewer` subagent (Drydock-flavored) against the PR for an internal review pass before requesting human reviewers.
- Suggest `gh pr ready` when the user is ready to flip from draft.

### 7. Report

```
Draft PR opened: <url>
├ Links to:   <owner>/<repo>#<N>
├ Parent:     <owner>/<repo>#<parent>          <!-- only if applicable -->
├ Active change: <slug>
└ Next:       /code-review or mark ready (`gh pr ready <PR>`)
```

## Guardrails

- If the branch is ahead of remote, offer to push first; do not push silently.
- If `tasks.md` has unchecked items, refuse to open a PR.
- Never force-push during PR prep.
- No GitHub Project hardcoding — only set Status if `config.yaml` declares a project.
