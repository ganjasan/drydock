# Workflow

Concrete, step-by-step: how a change goes from idea to merged code under Drydock.

## Quick reference

```
Idea
  │
  ▼
/dd:plan:add           ── captures idea as backlog item (GitHub issue)
  │
  ▼
/dd:plan:triage        ── assigns priority, area, phase
  │
  ▼
/dd:plan:promote       ── promotes issue to OpenSpec change in the right repo
  │
  ▼
/dd:build:start        ── creates branch + worktree + change skeleton
  │
  ├── /dd:build:explore  ── (optional) Q&A for ambiguous scope
  │
  ├── /dd:build:design   ── generate proposal + design + tasks
  │
  ├── /dd:build:code     ── implement from tasks list
  │
  └── /dd:build:test     ── run suite
  │
  ▼
/dd:ship:pr            ── open PR with linked change
  │
  ▼
 (review & merge)
  │
  ▼
/dd:ship:archive       ── archive change, sync deltas to specs
  │
  ▼
/dd:ship:release       ── (when appropriate) cut release, tag, changelog
```

Cross-cutting:

- `/dd:req:*` — requirements can be updated at any point; they often lead `/dd:plan:add`.
- `/dd:status` — show where you are (branch, worktree, open PRs, active change).
- `/dd:next` — suggest the next concrete action based on current state.

## Walkthrough: typical feature

### 0. Context

A feature request exists ("add a dark mode toggle") but is not yet captured.

### 1. Capture

```
/dd:plan:add "Dark mode toggle in header"
```

Creates a GitHub issue with the right labels and template.

### 2. Triage

```
/dd:plan:triage
```

Assigns `Priority: P2`, `Area: ui/theming`, `Phase: MVP+1`.

### 3. Promote to a change

```
/dd:plan:promote <issue-number>
```

Creates `openspec/changes/2026-05-01-dark-mode-toggle/` with:

- `proposal.md` — what and why.
- `design.md` — how (technical decisions).
- `tasks.md` — checklist.
- `deltas/` — specs updates.

### 4. Start building

```
/dd:build:start <change-id>
```

Creates a git worktree, checks out a branch, opens the change in context.

### 5. Explore (if needed)

```
/dd:build:explore
```

Q&A mode. Output lands back into `proposal.md` / `design.md`.

### 6. Design

```
/dd:build:design
```

Generates or updates the three OpenSpec artifacts based on current understanding.

### 7. Code

```
/dd:build:code
```

Pick up the next unchecked task in `tasks.md`. Drydock marks items complete as they ship.

### 8. Test

```
/dd:build:test
```

Runs the repo's suite per conventions (real DB for integration, GIVEN/WHEN/THEN docstrings, etc. — whatever the repo's CLAUDE.md declares).

### 9. PR

```
/dd:ship:pr
```

Opens a PR with links back to the change, the originating issue, and any traces.

### 10. Merge

Happens externally (reviewer, CI). Drydock doesn't auto-merge.

### 11. Archive

```
/dd:ship:archive
```

Runs verification (`traces-linter` subagent), syncs deltas from the change into `openspec/specs/`, archives the change.

### 12. Release (when appropriate)

```
/dd:ship:release
```

Determines release order (if multi-repo), runs gates, bumps version, generates changelog, tags.

## Exception list: trivial changes

These do NOT require a full OpenSpec change. Commit directly on a feature branch + PR:

- Typo fixes in docs or comments.
- README / LICENSE / CONTRIBUTING polish.
- Dependency version bumps with no API impact.
- Reordering imports, whitespace, lint-only fixes.
- Adjusting `.gitignore` / editor configs.

Anything that changes **observable behavior** — even by one character — goes through the full loop.

## Dogfooding self-check

If you are working *inside* the Drydock repository itself, every rule above applies to Drydock's own development. That's the whole point of ADR-0002.

## See also

- [methodology.md](methodology.md) — the *why*.
- [skills-catalog.md](skills-catalog.md) — the library of skills invoked by these commands.
- [migration-from-apz.md](migration-from-apz.md) — if you are coming from internal APZ.
