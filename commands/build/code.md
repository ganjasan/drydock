---
description: Resume implementation in the active branch/worktree — picks up the next unchecked task from OpenSpec
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, SlashCommand
---

Continue work on the currently active OpenSpec change. Reads `tasks.md`, finds the first unchecked item, implements it, runs tests if applicable, marks it complete, and commits.

## Procedure

1. **Identify active change.** Scan `openspec/changes/<slug>/.openspec.yaml` for the first directory whose status is not `done`. If none — suggest `/dd:next`.

2. **Branch sanity.** Verify we are on a non-`main` branch. If on `main`, warn — implementing main-tree is allowed but discouraged.

3. **Read `tasks.md`.** Find the first task with `- [ ]`.

4. **Delegate to `/opsx:apply`.** Pass the task text explicitly so the implementation step is unambiguous.

5. **Verify post-conditions:**
   - `git diff` is non-empty (real code changed).
   - Tests added or modified per repo conventions (check `CLAUDE.md` for test pattern; default is GIVEN/WHEN/THEN docstrings if specified).
   - Local lint / type-check / format pass (run repo-specific commands; do not assume a particular toolchain).

6. **Check off the task** in `tasks.md`: replace `- [ ]` with `- [x]`.

7. **Stage and commit:**

   ```
   <change-slug>: <task text, one short line>

   Refs: <owner>/<repo>#<issue-number>
   OpenSpec: openspec/changes/<change-slug>/tasks.md task <N>

   Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
   ```

8. **Report progress:**
   - If more tasks remain → offer to continue (`/dd:build:code` again).
   - If all tasks are checked → suggest `/dd:build:test` for full regression, then `/dd:ship:pr`.

## Guardrails

- Never skip tests. If the task is intrinsically test-less (e.g., docs-only edit), state that explicitly in the commit message.
- Never commit `.openspec.yaml` with `status: done` — that happens only at archive time.
- If `git status` shows unrelated changes, surface them to the user before committing; do not bundle.
- Never push automatically — pushing is an explicit step elsewhere.
