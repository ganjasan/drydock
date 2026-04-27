---
description: Generate OpenSpec artifacts (proposal + design + tasks) for the active change
allowed-tools: SlashCommand, Read, Bash
---

Wrapper around `/opsx:ff` (fast-forward) or `/opsx:continue` (step-by-step). Picks the right one based on existing artifacts.

## Procedure

1. Determine the active OpenSpec change in the current repo: scan `openspec/changes/<slug>/.openspec.yaml` for the first directory whose status is not `done`.

2. Check which artifacts exist:
   - `proposal.md`
   - `design.md`
   - `tasks.md`
   - `specs/` delta directory

3. Dispatch:
   - **NONE** of the above exist → invoke `/opsx:ff` (generate all artifacts at once).
   - **SOME** exist → invoke `/opsx:continue` (fill the next missing one).
   - **ALL** exist → suggest `/dd:build:code` to begin implementation.

4. After generation, print a summary:

   ```
   OpenSpec change: <slug>
   ├ proposal.md  ✓
   ├ design.md    ✓
   ├ tasks.md     ✓ (N tasks, 0 done)
   └ specs/       ✓ (M delta files)

   Ready to implement: /dd:build:code
   ```

## Guardrails

- If `.openspec.yaml` reports `status: done` — refuse; the change is archived.
- If `tasks.md` ends up with more than ~15 tasks — warn that tasks should be < 1 day each. Offer to split the change.
- Never silently overwrite an existing artifact; `/opsx:continue` knows how to advance without clobbering.
