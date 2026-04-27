---
description: Verify the active change — tasks all checked, specs deltas consistent, design references match
allowed-tools: SlashCommand, Read, Bash
---

Thin wrapper around the `openspec-verify-change` skill. Run before `/dd:ship:archive` to confirm the change is internally coherent.

## Procedure

1. Resolve the active change in the current repo (or accept an explicit `$ARGUMENTS` slug).

2. Invoke the `openspec-verify-change` skill.

3. The skill checks:
   - Every task in `tasks.md` is `- [x]`.
   - Every spec delta in `specs/` references a valid capability and contains required scenarios.
   - Frontmatter cross-references in `proposal.md` and `design.md` resolve to existing files.
   - `.openspec.yaml` does not yet have `status: done` (archive sets that, not verify).

4. Print a structured report. If any check fails, list specifics and suggest the targeted fix command.

## Guardrails

- Read-only: never modify the change to make verification pass.
- If verification fails, do not advance to archive — return to `/dd:build:code` or `/opsx:continue`.
