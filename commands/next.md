---
description: Suggest the next concrete action in the Drydock workflow based on observed state
allowed-tools: Bash, Read, Glob, Grep
---

Analyze the current workflow state of the repo and propose exactly one next step. If multiple reasonable options exist, list them ranked with a single recommendation at the top.

Load merged Drydock configuration via `source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load`. Read GitHub Project reference (`cfg_has github.project.number`, `cfg_get github.project.number`, `cfg_get github.project.name`) and triage label (`cfg_get github.triage_label`, default `status/needs-triage`). The merged config draws from plugin-root → `~/.drydock/config.yaml` → `<repo>/.drydock/config.yaml`.

## Decision logic

Work through these checks in order; emit the **first** match as the suggested next step.

### 0. Raw inbox is non-empty

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
inbox_dir="<repo-root>/${incoming}"
```

If `${inbox_dir}` exists and contains one or more `*.md` files:

→ `/dd:raw:process` — classify · dedup · cross-link the inbox before starting new work. Cite the file count.

This check is intentionally first: it's cheap, the data has provenance, and processing the inbox often surfaces parent-work that should jump the queue.

### 1. Active OpenSpec change with unfinished work

If the current repo contains `openspec/changes/<slug>/.openspec.yaml` with status not `done`:

- `proposal.md` missing → suggest `/opsx:continue` (or `/opsx:new` if the change directory is otherwise empty)
- `design.md` missing → `/opsx:continue`
- `tasks.md` missing → `/opsx:continue`
- `tasks.md` has unchecked items → `/dd:build:code` (resumes implementation at the next task)
- All tasks checked → `/opsx:verify` then `/dd:ship:archive`

### 2. Branch ahead of origin/main without a PR

If on a `feature/*` branch with commits not on the remote, OR no open PR for the branch:

→ `/dd:ship:pr` — open a PR linked to the issue and active change.

### 3. Untriaged GitHub issues (configured project only)

If `cfg_has github.project.number` AND the repo has issues labeled with `cfg_get github.triage_label` (default `status/needs-triage`):

→ `/dd:plan:triage` — batch triage pass.

### 4. Clean main with no work in flight

- If `cfg_has github.project.name`, mention the project name in the prompt: "Project `<name>` is up to date. Pick an issue, or start a new change."
- Without a configured project, simply: "Clean state. Pick an issue or start a new change with `/dd:build:start <issue>`."

### 5. Nothing to do

→ Tell the user they are up to date. Offer:

- `/dd:plan:add` to capture a new idea as a backlog issue.
- `/dd:req:vision`, `/dd:req:adr`, etc. — work on requirements documents instead.

## Output format

Under 10 lines. Structure:

```
Suggested next: <command>  — <one-line reason>

Why: <2-3 sentences explaining the observed state that led to this suggestion>
Alternative(s): <other reasonable options, if any>
```

## Guardrails

- Never assume a project board exists if `cfg_has github.project.number` returns false.
- Base every suggestion on observed state (filesystem, git, `gh`) — never fabricate.
- If neither active change, branch state, nor untriaged issues are observable, default to "you are up to date" rather than guessing.
