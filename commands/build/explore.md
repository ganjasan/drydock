---
description: Q&A mode for ambiguous scope — wraps /opsx:explore
allowed-tools: SlashCommand
---

Thin wrapper around `/opsx:explore` — a thinking partner for clarifying requirements before writing OpenSpec artifacts. Use when scope is unclear or when there are multiple plausible approaches.

## Procedure

1. If an active OpenSpec change exists in the current repo, anchor the explore session to it (so ideas flow back into `proposal.md`).

2. If no change yet — start from the linked issue (via `feature/<N>-*` branch name or `$ARGUMENTS`).

3. Invoke `/opsx:explore`.

4. When the user exits explore mode, suggest next:
   - `/dd:build:design` — generate proposal/design/tasks now that scope is clearer.
   - `/dd:build:code` — go straight to implementation if design is already firm.
