# Workflow

Concrete, step-by-step: how a piece of work goes from external signal to merged code under Drydock.

## Quick reference

```
External signal
   (email · meeting · client request · Notion page · Linear issue · upstream GitHub issue)
  │
  ▼
/dd:raw:capture            ── manual log into raw/_incoming/
/dd:raw:ingest-{source}    ── scheduled / on-demand pull from {gmail, calendar, drive, notion, linear, github}
  │
  ▼
/dd:raw:process            ── classify · dedup · cross-link · suggest backlog items
  │
  ▼
(optional)  /dd:req:*       ── vision · stakeholder · use-case · ADR · review
  │
  ▼
/dd:plan:add               ── captures intent as backlog item (GitHub issue)
  │
  ▼
/dd:plan:triage            ── assigns priority, area, phase, parent
  │
  ▼
/dd:plan:promote           ── promotes issue to OpenSpec change in the right repo (Area → repo routing)
  │
  ▼
/dd:build:start            ── creates branch (+ optional worktree) + change skeleton
  │
  ├── /dd:build:explore    ── (optional) Q&A for ambiguous scope
  │
  ├── /dd:build:design     ── generate proposal + design + tasks
  │       (or /dd:build:ff for well-understood work — generates all in one pass)
  │
  ├── /dd:build:code       ── implement from tasks list
  │
  ├── /dd:build:test       ── run suite per repo conventions
  │
  └── /dd:build:verify     ── pre-archive check: tasks complete · deltas consistent · refs resolve
  │
  ▼
/dd:ship:pr                ── open PR with linked change (runs <repo>/.drydock/hooks/pre-pr.sh if present)
  │
  ▼
 (review & merge)
  │
  ▼
/dd:ship:archive           ── archive change · sync deltas → openspec/specs/
  │
  ▼
/dd:ship:release           ── (when appropriate) runs release.gates · cut release · tag · changelog · propagate pins
```

Cross-cutting:

- **`/dd:status`** — show where you are (branch, worktree, open PRs, active change, raw inbox).
- **`/dd:next`** — suggest the next concrete action based on observed state.
- **`/dd:req:*`** — requirements can be updated at any point; they often *follow* `/dd:raw:process` (a clear pattern emerges from many raw signals → time for a use case or ADR) and *precede* `/dd:plan:add`.

## Walkthrough: typical feature, from inbox to release

### 0. External signal arrives

A client sends an email asking for a dark mode. A standup is scheduled. A teammate drops a Loom in Drive.

### 1a. Capture (manual)

```
/dd:raw:capture
```

Lands in `raw/_incoming/2026-04-27-client-dark-mode-request.md` with frontmatter (source, date, parties involved, raw text or link).

### 1b. Or ingest (bulk, scheduled)

```
/dd:raw:ingest-gmail
/dd:raw:ingest-calendar
/dd:raw:ingest-notion
```

Each pulls from the corresponding source per `<repo>/.drydock/config.yaml` (filters, labels, DB IDs). Items land in `raw/_incoming/` with the same frontmatter shape.

### 2. Process the inbox

```
/dd:raw:process
```

Classifies items into `raw/meetings/`, `raw/feedback/`, `raw/ideas/`, `raw/competitors/`, `raw/client-boards/`. Dedups. Cross-links to existing requirements / open issues. Suggests backlog items where pattern is clear.

The post-capture hook (`<repo>/.drydock/hooks/post-capture.sh`) runs after each item is filed, if the file exists — useful for frontmatter linting or content-guard checks.

### 3. (Optional) Update requirements

If raw signals reveal a new actor, scenario, or constraint:

```
/dd:req:use-case        # write the new use case
/dd:req:adr             # record any architectural decision the signal forced
/dd:req:review          # check requirements quality before promoting to plan
```

Skip this step for narrow, obvious work.

### 4. Capture as backlog item

```
/dd:plan:add "Dark mode toggle in header"
```

Creates a GitHub issue with the right labels and template (per `config.yaml`).

### 5. Triage

```
/dd:plan:triage
```

Assigns `Priority: P2`, `Area: ui/theming`, `Phase: MVP+1`, parent epic if any.

### 6. Promote to a change

```
/dd:plan:promote <issue-number>
```

Resolves the target repo via `area_to_repo` in `config.yaml`, creates `openspec/changes/2026-05-01-dark-mode-toggle/` with `proposal.md`, `design.md`, `tasks.md`, `deltas/`.

### 7. Start building

```
/dd:build:start <change-id>
```

Creates a branch (and worktree if `worktree.enabled: true`), checks out, opens the change in context.

### 8. Explore (if needed)

```
/dd:build:explore
```

Q&A mode. Output lands back into `proposal.md` / `design.md`.

### 9. Design

```
/dd:build:design
```

Generates or updates the three OpenSpec artifacts based on current understanding. For well-understood work:

```
/dd:build:ff
```

does proposal + design + tasks + deltas in one pass.

### 10. Code

```
/dd:build:code
```

Pick up the next unchecked task in `tasks.md`. Drydock marks items complete as they ship.

### 11. Test

```
/dd:build:test
```

Runs the repo's suite per conventions (real DB for integration, GIVEN/WHEN/THEN docstrings, etc. — whatever the repo's `CLAUDE.md` declares).

### 12. Verify

```
/dd:build:verify
```

Pre-archive sanity check.

### 13. PR

```
/dd:ship:pr
```

Runs `<repo>/.drydock/hooks/pre-pr.sh` if present (e.g. public-ready guards, frontmatter lint). On success, opens a PR with links back to the change, the originating issue, and any traces.

### 14. Merge

Happens externally (reviewer, CI). Drydock doesn't auto-merge.

### 15. Archive

```
/dd:ship:archive
```

Runs verification (`traces-linter` subagent), syncs deltas from the change into `openspec/specs/`, archives the change.

### 16. Release (when appropriate)

```
/dd:ship:release
```

Runs `release.gates` from `config.yaml` in order — for example: `[/dd:build:test, /conformance, /parity]`. Each gate must exit clean. Then bumps version, generates changelog, tags. If `release.repos` declares dependents, the `release-coordinator` subagent determines order and propagates version pins.

The pre-release hook (`<repo>/.drydock/hooks/pre-release.sh`) runs before any gate, if present.

## End-to-end shortcut: `/dd:feature`

When you already know the next eight commands you would type, `/dd:feature` runs them for you with explicit pause points at each checkpoint. It is a convenience over the per-phase chain — not a replacement.

```
/dd:feature "add a dark-mode toggle in the header"
  │
  ├ phase 1 — capture idea          (skills/raw-capture)
  │   pause: review the filed idea, [c]ontinue
  │
  ├ phase 2 — explore code           (dd:code-explorer agent, output cached)
  │
  ├ phase 3 — clarify                (skills/feature-clarify)
  │   pause: review captured answers, [c]ontinue
  │
  ├ phase 4 — issue + change         (/dd:plan:add → /dd:plan:promote)
  │
  ├ phase 5 — branch + worktree      (/dd:build:start)
  │
  ├ phase 6 — architecture           (dd:code-architect agent, reuses cached exploration)
  │   pause: review design.draft.md, [c]ontinue (promotes to design.md)
  │
  ├ phase 7 — design + tasks         (/dd:build:design)
  │
  ├ phase 8 — implement              (/dd:build:code looped over tasks)
  │
  ├ phase 9 — test                   (/dd:build:test)
  │
  └ phase 10 — draft PR              (/dd:ship:pr)
      pause: review PR body, then `gh pr ready <N>` when ready
```

Default pauses: `idea`, `clarify`, `design`, `pr`. Tune via `feature.pause_after.<phase>` per `docs/extension-model.md` § feature.

Stepping out at any pause leaves the workspace recoverable. The orchestrator prints the resume hint citing the per-phase command that picks up from there — for example, after stopping at the architecture pause:

```
Stopped at phase 6 (architecture).
Saved: openspec/changes/<slug>/design.draft.md
Resume with: /dd:build:design  (or rerun /dd:feature to continue from here)
```

`/dd:feature` does NOT auto-merge the PR, auto-archive the change, or auto-cut a release. The flow ends at "draft PR opened"; everything beyond is human review and the existing `/dd:ship:archive` / `/dd:ship:release` commands.

The per-phase commands listed above remain canonical. Use them when you want fine-grained control or when the orchestrator's defaults do not fit (e.g. you have already filed the issue manually — flip `feature.idea_destination: skip` and `/dd:feature` starts at issue creation; or use `/dd:plan:add` directly).

## Exception list: trivial changes

These do **not** require a full OpenSpec change. Commit directly on a feature branch + PR:

- Typo fixes in docs or comments.
- README / LICENSE / CONTRIBUTING polish.
- Dependency version bumps with no API impact.
- Reordering imports, whitespace, lint-only fixes.
- Adjusting `.gitignore` / editor configs.

Anything that changes **observable behavior** — even by one character — goes through the full loop.

The `raw → req` segment is also skippable for trivial work that originated inside your own head, not from an external signal. The phases are a checklist, not a forced march.

## Project-specific specifics

If a step in this walkthrough seems to do something Apilize-flavored (Gmail filters for a specific client, conformance gate, public-ready guard) — that behavior lives in the consuming repo's `<repo>/.drydock/config.yaml`, `<repo>/.drydock/hooks/`, or `<repo>/.claude/commands/`. The Drydock plugin code itself never names a specific organization. See [extension-model.md](extension-model.md).

## Dogfooding self-check

If you are working *inside* the Drydock repository itself, every rule above applies to Drydock's own development. That's the whole point of [ADR-0002](../requirements/adr/0002-dogfooding-as-principle.md).

## See also

- [methodology.md](methodology.md) — the *why* of the five phases.
- [extension-model.md](extension-model.md) — config schema, hook lifecycle, command-reference contract.
- [skills-catalog.md](skills-catalog.md) — the library of skills invoked by these commands.
- [migration-from-apz.md](migration-from-apz.md) — for users moving off the internal APZ plugin.
