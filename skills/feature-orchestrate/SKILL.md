---
name: feature-orchestrate
description: Walk a single idea through all ten Drydock phases — raw capture, code exploration, structured clarification, issue + change, branch, architecture, design + tasks, implementation, tests, draft PR. Pauses at configurable checkpoints; never bypasses phase gates. Standalone-invokable; also wrapped by /dd:feature.
---

You are the feature-orchestrate skill. Your job is to sequence the existing per-phase Drydock commands and skills into a single end-to-end flow, pausing at configurable checkpoints, and to leave the workspace in a recoverable state if the user steps out at any phase.

You MUST NOT reimplement what the per-phase commands do. You call them. If the user is going to type `/dd:plan:add` themselves at phase 4, your job is to type it for them with the right arguments — not to file the issue yourself.

## Setup

Load merged Drydock config and the feature-state helper:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh";        dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/feature_state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
```

## Inputs

- `idea` — a one-line statement of the feature/bug/task to flow. Required for new flows; on resume, the orchestrator reads it from the linked raw entry or the active OpenSpec change's frontmatter.
- `mode` — `new` (start at phase 1) or `resume` (start at the phase reported by `dd_feature_position`).

## The phase table

| # | Name | What happens | Delegates to |
|---|---|---|---|
| 1 | idea | File the idea as a raw entry | `skills/raw-capture` (synthetic frontmatter) |
| 2 | explore | Map relevant code | `dd:code-explorer` agent — once, cached |
| 3 | clarify | Structured Q&A | `skills/feature-clarify` |
| 4 | promote | Issue + OpenSpec change | `/dd:plan:add` then `/dd:plan:promote` |
| 5 | start | Branch + worktree | `/dd:build:start` |
| 6 | architect | Architecture proposal | `dd:code-architect` agent (uses cached exploration) |
| 7 | design | proposal/design/tasks | `/dd:build:design` |
| 8 | code | Implement task-by-task | `/dd:build:code` (looped until tasks.md is fully checked) |
| 9 | test | Run the suite | `/dd:build:test` |
| 10 | pr | Open draft PR | `/dd:ship:pr` |

The phase names align with `dd_feature_position` return values (see `lib/feature_state.sh`).

## Default pause cadence

`feature.pause_after.<phase>` (boolean, per-phase). Built-in defaults:

| Phase | Default `pause_after` |
|---|---|
| `idea` | `true` |
| `explore` | `false` |
| `clarify` | `true` |
| `promote` | `false` |
| `design` (after architect on phase 6 + design.md applied on phase 7) | `true` |
| `code` | `false` |
| `test` | `false` |
| `pr` | `true` |

A pause prompts:

```
Phase <N> done — <one-line summary>.
[c] continue · [s] stop here · [r] redo this phase · [j] jump to phase: __

Default: c (Enter to continue)
```

- `c` (or Enter) — continue to the next phase.
- `s` — exit cleanly. Print the resume hint citing the per-phase command for the next pending step.
- `r` — re-run the current phase. For `explore`: deletes the cached exploration and re-invokes `dd:code-explorer`. For other phases: re-invokes the underlying command/skill.
- `j <N>` — jump to phase N. Forward jumps skip intermediate phases (warn if artifacts are missing); backward jumps abort with a message naming the per-phase command that re-does that step manually.

## Procedure

### 0. Resolve mode and starting phase

If `mode == new`:
- Set `current_phase = 1` (idea).
- Persist the idea string in memory for use by phase 1.

If `mode == resume`:
- Call `dd_feature_position`. Map its return value to the phase index per the phase table.
- If it returns `none`, behave as if `mode == new`.
- Print: `Detected: phase <N> (<phase-name>). Last artifact: <one-line>. Continuing at phase <N+1>: <next-phase>.`

### Phase 1 — Capture idea

Skip this phase entirely if `cfg_get feature.idea_destination` returns `skip`. Note the skip in the run log and proceed to phase 2.

Otherwise: invoke the `raw-capture` skill with the idea body and synthetic metadata:

```yaml
source: manual
proposed_category: ideas
captured_by: claude-code:/dd:feature
```

`raw-capture` computes the `dedup_key` as `manual:<sha-of-body>`, writes to the configured ideas subdir (or `_incoming/` if your raw setup files everything there first), and fires the `post-capture` hook.

Record the idea entry's path in memory — phases 4 and 8 will cite it for traceability (`traces_to.raw`).

Pause if `cfg_get feature.pause_after.idea == "true"`.

### Phase 2 — Explore the code

Dispatch `dd:code-explorer` exactly once. Pass the idea string as the topic. Capture the agent's output verbatim and write it to `<workdir>/.feature-exploration.md` with frontmatter:

```yaml
---
cached_at: <ISO 8601 UTC>
idea_dedup_key: <the dedup_key from phase 1, or "skipped" if phase 1 was skipped>
---
```

`<workdir>` is the current repo root before phase 4 creates the change directory. Once the change exists (after phase 4), the cache file is moved to `<change>/.exploration.md`.

The cache is gitignored — its purpose is in-flow reuse, not version control. The orchestrator must add the gitignore entry on first cache write if `<repo-root>/.gitignore` does not already cover `.feature-exploration.md` and `<change>/.exploration.md`.

Pause if `cfg_get feature.pause_after.explore == "true"` (default `false`).

### Phase 3 — Clarifying questions

Invoke the `feature-clarify` skill. Pass:
- The idea string.
- The contents of the cached exploration as grounding context.
- The pending OpenSpec change path (if one exists from a prior resume — usually not at this phase).

`feature-clarify` runs the closed-form Q&A loop, returning a list of `(question, answer)` pairs and any `?`-deferred questions to surface as Open Questions on phase 7.

Stash the answers in `<workdir>/.feature-clarifying-answers.md` (gitignored). Phase 7 reads them when assembling `proposal.md`.

Pause if `cfg_get feature.pause_after.clarify == "true"` (default `true`).

### Phase 4 — Issue + OpenSpec change

Invoke `/dd:plan:add` with type derived from the idea (default `feature`; override if the idea text indicates `bug` or `task`) and a title derived from the idea string (kebab-truncated to ~60 chars). Capture the resulting issue number.

Then invoke `/dd:plan:promote <issue-number>` to scaffold `openspec/changes/<slug>/`.

After the change exists:
- Move `<workdir>/.feature-exploration.md` → `<change>/.exploration.md` (preserve frontmatter).
- Move `<workdir>/.feature-clarifying-answers.md` → `<change>/.feature-clarifying-answers.md`.
- Append a `traces_to.raw: [<idea-entry-path>]` link to the change's `.openspec.yaml` frontmatter, if phase 1 produced an entry.

Pause if `cfg_get feature.pause_after.promote == "true"` (default `false`).

### Phase 5 — Branch + worktree

Invoke `/dd:build:start <issue-number>`. This creates the feature branch (and worktree, if `worktree.enabled: true`) and seeds the change directory's `.openspec.yaml` with `linked_issue` and any `Area`/`Phase`/`Priority` from project fields.

Subsequent phases run inside the worktree if one was created.

There is no `feature.pause_after.start` knob — branch creation always auto-continues; the next pause is the design pause after phase 6.

### Phase 6 — Architecture

Dispatch `dd:code-architect` with a prompt that includes:
- The idea statement.
- The full body of the cached exploration file (`<change>/.exploration.md`), labeled clearly as ground truth.
- The clarifying answers from `<change>/.feature-clarifying-answers.md`.
- An explicit instruction: **"Do not re-traverse the codebase. Use the exploration as ground truth. If a cited file no longer exists at the same path, flag it; do not re-search."**

Write the architect's output to `<change>/design.draft.md`. Do NOT replace `design.md` yet — the user reviews on the design pause.

Pause if `cfg_get feature.pause_after.design == "true"` (default `true`).

If the user accepts at the pause (`c`), promote the draft: `mv <change>/design.draft.md <change>/design.md` (or merge if `design.md` already had stub content from `/dd:plan:promote`).

### Phase 7 — Design + tasks

Invoke `/dd:build:design`. This runs `/opsx:ff` (or `/opsx:continue` if `proposal.md`/`design.md` already exist, which they do at this point — `proposal.md` from `/dd:plan:promote`, `design.md` from phase 6). The skill fills in `tasks.md` and `specs/` deltas based on the proposal and design.

Before invoking, append to `<change>/proposal.md` § Context the clarifying answers (from `<change>/.feature-clarifying-answers.md`) under a `### Clarifying answers` subsection. Append any `?`-deferred questions to `<change>/design.md` § Open Questions.

Pause is the same `feature.pause_after.design` flag — but it has already paused once after phase 6. Skip the pause here; phase 7 just produces tasks.md.

### Phase 8 — Implementation loop

Invoke `/dd:build:code` repeatedly until `tasks.md` has zero unchecked items. Each invocation picks up the next `- [ ]` task, implements it, runs scoped tests, marks the task `- [x]`, and commits.

Pause between tasks if `cfg_get feature.pause_after.code == "true"` (default `false`).

If `/dd:build:code` reports a failure (test failed, lint broken, etc.), exit with the resume hint pointing at `/dd:build:code` so the user can investigate.

### Phase 9 — Tests

Invoke `/dd:build:test` for the full-suite regression. If it fails, exit with the resume hint.

Pause if `cfg_get feature.pause_after.test == "true"` (default `false`).

### Phase 10 — Draft PR

Invoke `/dd:ship:pr`. This runs the `pre-pr` hook (if present) and opens a draft PR linking the issue and the change.

Pause if `cfg_get feature.pause_after.pr == "true"` (default `true`). The pause here is for the user to review the PR body before flipping it from draft to ready — the orchestrator does NOT auto-promote.

Print the terminal report and exit successfully:

```
/dd:feature → done
├ Idea:        <one-line>
├ Raw entry:   <path>            (or "skipped")
├ Issue:       <owner>/<repo>#<N>
├ Change:      <slug>
├ Branch:      <branch>
├ Worktree:    <path or "—">
├ PR (draft):  <url>
└ Next:        Review the PR body, then `gh pr ready <N>` when ready
```

## Resume hints (per-phase exit messages)

When the user exits with `s` at any pause, print one of:

| Exited after phase | Resume hint |
|---|---|
| 1 idea | `Resume: rerun /dd:feature (or /dd:plan:add to file an issue manually)` |
| 2 explore | `Resume: rerun /dd:feature (cached exploration at <path>; reuse on next run)` |
| 3 clarify | `Resume: rerun /dd:feature (or /dd:plan:add to file the issue with answers in body)` |
| 4 promote | `Resume: /dd:build:start <issue-number>` |
| 5 start | `Resume: /dd:build:design` |
| 6 architect | `Resume: /dd:build:design (architect draft at <change>/design.draft.md)` |
| 7 design | `Resume: /dd:build:code` |
| 8 code | `Resume: /dd:build:code (tasks.md: <X>/<Y> done)` |
| 9 test | `Resume: /dd:ship:pr` |
| 10 pr | `(terminal — no further auto-step)` |

## State detection (no state file)

`/dd:feature` does not write its own phase-state file. On `mode == resume`, call `dd_feature_position` to determine the current phase from artifacts (raw entry, GitHub issues, OpenSpec change, branch, tasks.md, PR). The exploration cache and clarifying-answers scratch files are pre-artifact intermediate outputs — their presence does NOT affect `dd_feature_position`'s return value; that comes purely from the artifact graph.

## Guardrails

- **Single exploration pass per flow.** `dd:code-explorer` is dispatched exactly once on phase 2. Phase 6 reuses the cached output via the architect's prompt and explicitly forbids the architect from re-traversing.
- **No phase-state file.** The orchestrator never writes `.feature-state.*` or similar. State is derived from artifacts.
- **No bypass of phase gates.** Default pauses on `idea`, `clarify`, `design`, `pr` are not negotiable inside this skill; users disable them via `feature.pause_after.<phase>: false` in their config.
- **No auto-merge / auto-archive / auto-release.** The flow ends at "draft PR opened". `/dd:ship:archive` and `/dd:ship:release` remain explicit.
- **No inline phase logic.** Every phase delegates to the corresponding existing command/skill; if a per-phase command behaves a certain way, this orchestrator inherits that behavior, not a copy of it.
- **Recoverable exits everywhere.** Any `s` choice or interrupted run leaves the workspace such that the named per-phase command picks up cleanly.
- **Universal — no organization-specific values.** Nothing in this skill body references a specific company, client, product, or repo.
