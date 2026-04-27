---
description: Fast-forward — generate proposal, design, tasks, and specs for the active change in one pass
allowed-tools: SlashCommand
---

Thin wrapper around the `openspec-ff-change` skill. Use when the work is well-scoped and you want all OpenSpec artifacts generated at once, then apply them.

## Procedure

1. Determine the active OpenSpec change (or ask for a name if none exists).

2. Invoke the `openspec-ff-change` skill, passing the change name and any context the user provided.

3. The skill drives the `openspec` CLI to scaffold the change, then generates `proposal.md`, `design.md`, `tasks.md`, and `specs/` deltas.

4. After generation, suggest `/dd:build:code` (or `/dd:build:verify` if the user wants to inspect first).

## Guardrails

- If `tasks.md` ends up with > 15 tasks, surface a warning and offer to split the change. Tasks should be roughly < 1 day each.
- Do not invoke `/opsx:ff` if a change already has any artifact — switch to `/opsx:continue` to avoid overwriting.
