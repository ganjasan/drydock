# Workflow

Concrete, step-by-step: how a change goes from idea to merged code under Shipwright.

## Quick reference

```
Idea
  │
  ▼
/sw:plan:add           ── captures idea as backlog item (GitHub issue)
  │
  ▼
/sw:plan:triage        ── assigns priority, area, phase
  │
  ▼
/sw:plan:promote       ── promotes issue to OpenSpec change in the right repo
  │
  ▼
/sw:build:start        ── creates branch + worktree + change skeleton
  │
  ├── /sw:build:explore  ── (optional) Q&A for ambiguous scope
  │
  ├── /sw:build:design   ── generate proposal + design + tasks
  │
  ├── /sw:build:code     ── implement from tasks list
  │
  └── /sw:build:test     ── run suite
  │
  ▼
/sw:ship:pr            ── open PR with linked change
  │
  ▼
 (review & merge)
  │
  ▼
/sw:ship:archive       ── archive change, sync deltas to specs
  │
  ▼
/sw:ship:release       ── (when appropriate) cut release, tag, changelog
```

Cross-cutting:

- `/sw:req:*` — requirements can be updated at any point; they often lead `/sw:plan:add`.
- `/sw:status` — show where you are (branch, worktree, open PRs, active change).
- `/sw:next` — suggest the next concrete action based on current state.

## Walkthrough: typical feature

### 0. Context

A feature request exists ("add a dark mode toggle") but is not yet captured.

### 1. Capture

```
/sw:plan:add "Dark mode toggle in header"
```

Creates a GitHub issue with the right labels and template.

### 2. Triage

```
/sw:plan:triage
```

Assigns `Priority: P2`, `Area: ui/theming`, `Phase: MVP+1`.

### 3. Promote to a change

```
/sw:plan:promote <issue-number>
```

Creates `openspec/changes/2026-05-01-dark-mode-toggle/` with:

- `proposal.md` — what and why.
- `design.md` — how (technical decisions).
- `tasks.md` — checklist.
- `deltas/` — specs updates.

### 4. Start building

```
/sw:build:start <change-id>
```

Creates a git worktree, checks out a branch, opens the change in context.

### 5. Explore (if needed)

```
/sw:build:explore
```

Q&A mode. Output lands back into `proposal.md` / `design.md`.

### 6. Design

```
/sw:build:design
```

Generates or updates the three OpenSpec artifacts based on current understanding.

### 7. Code

```
/sw:build:code
```

Pick up the next unchecked task in `tasks.md`. Shipwright marks items complete as they ship.

### 8. Test

```
/sw:build:test
```

Runs the repo's suite per conventions (real DB for integration, GIVEN/WHEN/THEN docstrings, etc. — whatever the repo's CLAUDE.md declares).

### 9. PR

```
/sw:ship:pr
```

Opens a PR with links back to the change, the originating issue, and any traces.

### 10. Merge

Happens externally (reviewer, CI). Shipwright doesn't auto-merge.

### 11. Archive

```
/sw:ship:archive
```

Runs verification (`traces-linter` subagent), syncs deltas from the change into `openspec/specs/`, archives the change.

### 12. Release (when appropriate)

```
/sw:ship:release
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

If you are working *inside* the Shipwright repository itself, every rule above applies to Shipwright's own development. That's the whole point of ADR-0002.

## See also

- [methodology.md](methodology.md) — the *why*.
- [skills-catalog.md](skills-catalog.md) — the library of skills invoked by these commands.
- [migration-from-apz.md](migration-from-apz.md) — if you are coming from internal APZ.
