---
description: Finalize an OpenSpec change after PR is merged — verify, sync delta→main specs, archive
allowed-tools: Bash, SlashCommand
---

Run after a PR is merged. Wraps `openspec-verify-change` → `openspec-archive-change` → `openspec-sync-specs` and (optionally) closes the linked issue.

## Procedure

1. Determine the active change in the current repo, or accept an explicit `$ARGUMENTS` slug.

2. Invoke `openspec-verify-change` skill — confirm implementation matches design and all checks pass.

3. Invoke `openspec-archive-change` skill — set the change's `.openspec.yaml` `status: done` and move artifacts to the archive location per the openspec CLI.

4. Invoke `openspec-sync-specs` skill — fold delta specs from `openspec/changes/<slug>/specs/` into main `openspec/specs/`.

5. Optional issue close (only if `gh` is configured and the change frontmatter has `linked_issue`):

   ```
   gh issue close <N> --reason completed \
     --comment "Implemented in PR #<PR>; archived as openspec/specs/<spec>."
   ```

6. Optional project Status update (only if a project is configured): set Status → `Done` for the linked issue.

7. Report:

   ```
   Archived OpenSpec change: <slug>
   ├ Verify:    ✓
   ├ Sync:      <N> delta files folded into specs/
   ├ Archived:  openspec/changes/archive/<slug>.md
   ├ Issue:     <owner>/<repo>#<N> closed   (if applicable)
   └ Status:    Done                         (if applicable)
   ```

## Guardrails

- If verify fails, halt — do not archive a change that failed verification.
- Never modify specs outside the change's `specs/` delta during sync.
- Issue/project updates are optional and silent-skipped when not configured.
