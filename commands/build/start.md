---
description: Start work on a GitHub issue — create branch (and optional worktree), open the OpenSpec change skeleton
argument-hint: "<issue-ref>"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, SlashCommand
---

Begin a new feature/bug/task following the Drydock build loop. Defaults to a single-repo workflow on the current repository; multi-repo routing via Area mapping is opt-in.

Argument: `$ARGUMENTS` — issue reference. Accepted forms:
- `42` — issue number in the current repo
- `<owner>/<repo>#42` — issue in another repo
- full GitHub issue URL

## Procedure

Load Drydock config and helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh";       dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/area_routing.sh"
```

Use `dd_branch_name <issue> <slug>` for branch names, `dd_worktree_dir <issue> <slug>` for worktree paths, and `dd_resolve_area <area>` for routing. All keys have documented defaults; project-specific values come from `<repo>/.drydock/config.yaml`.

### Step 0: Resolve the issue

Via `gh issue view <ref> --json number,title,body,labels,url,projectItems` fetch metadata.

If the issue's project fields include `Area`, call `dd_resolve_area <area>`:
- Returns the absolute target path on success.
- Returns non-zero with a fail-loud diagnostic when `area_to_repo` is set but the requested area has no mapping (offers a copy-pasteable mapping to add to config).
- Returns the current repo when `area_to_repo` is unset entirely or when the value is `.`.

If the resolved path differs from the current repo, ask whether to switch (`cd "$resolved"`) before proceeding.

Extract a slug from the issue title via `lib/frontmatter.sh::fm_slug`.

### Step 1: Branch

Compute branch name via `dd_branch_name <issue-id> <slug>` (default template `feature/<issue-id>-<slug>`).

```bash
branch=$(dd_branch_name "$issue_id" "$slug")
git checkout -b "$branch"
```

If a branch with that name already exists locally — ask whether to reuse, choose a different slug, or abort.

### Step 2: Worktree (only if configured)

If `cfg_get worktree.enabled` is `true`:

```bash
wt_dir=$(dd_worktree_dir "$issue_id" "$slug")
mkdir -p "$(dirname "$wt_dir")"
git worktree add "$wt_dir" "$branch"
```

`dd_worktree_dir` composes `worktree.base_dir` + `worktree.naming` (defaults: `<repo>/.worktrees/wt-<issue-id>`).

**From this point all subsequent work happens in the worktree.**

If `cfg_get worktree.enabled` is `false` or absent: stay in the main checkout on the new branch.

### Step 3: Read context

Print to the user:
- Issue title and body.
- Parent epic if the issue is a sub-issue (fetch via `gh`).
- Linked ADRs / requirements files referenced in the body.

Optionally offer to spawn the `code-explorer` subagent (Drydock-flavored — searches by `traces_to` frontmatter alongside code) for an architecture pre-read.

### Step 4: Start the OpenSpec change

Invoke `/opsx:new` with the issue title (sanitized to a kebab slug). This creates `openspec/changes/<change-slug>/` with `.openspec.yaml`.

Record the linked issue in the change frontmatter:

```yaml
linked_issue: "<owner>/<repo>#<N>"
hub_parent: "<owner>/<repo>#<parent-N>"   # optional, only if sub-issue
```

This lets `/dd:status` and `/dd:next` find the connection.

### Step 5: Offer next-step mode

Ask the user:
- (a) `/opsx:explore` — Q&A before design (recommended if scope is ambiguous)
- (b) `/opsx:ff` — generate proposal/design/tasks at once (well-scoped work)
- (c) Pause here

Dispatch the chosen command.

### Step 6: Update the issue (optional, if `gh` is configured)

If the user has `gh` authenticated and the issue is in a project with a Status field:
- Set Status → `In progress`.
- Add a comment: `Started: branch \`<branch-name>\`<, worktree \`<wt-path>\`>, OpenSpec change \`<change-slug>\``.

Skip this step silently if no project is configured or the user lacks the scope.

## Output

```
Started issue #<N>  "<issue title>"
├ Repo:         <current-repo or routed-repo>
├ Branch:       <branch-name>
├ Worktree:     <path or "—">
├ OpenSpec:     openspec/changes/<change-slug>/
└ Next:         /opsx:continue  (or /dd:next)
```

## Guardrails

- Never overwrite an existing branch or worktree without asking.
- If the issue carries the configured triage label, refuse to start and suggest `/dd:plan:triage` first.
- If the user is already in a worktree, warn that starting another task means parallel work.
- Do not require `area_to_repo` configuration; absent the table, operate single-repo.
