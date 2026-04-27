---
description: Finalize an OpenSpec change after PR is merged — verify, sync delta→main specs, archive
allowed-tools: Bash, SlashCommand
---

Run after a PR is merged. Wraps `openspec-verify-change` → `openspec-archive-change` → `openspec-sync-specs` and (optionally) closes the linked issue. Load merged Drydock config (`source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load`) and the hook dispatcher (`source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"`).

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

6. Optional project Status update (only if `cfg_has github.project.id`): set Status → `Done` for the linked issue using `cfg_get github.project_fields.status.options.done`.

7. **Post-archive lifecycle hook**:

   ```bash
   extra=$(jq -cn --arg slug "$change_slug" '{change_slug: $slug}')
   dd_hook_invoke post-archive "$extra"   # warns on non-zero, does not roll back
   ```

   If `<repo>/.drydock/hooks/post-archive.sh` exists and is executable, it runs with the payload on stdin. Per the extension-model contract: `post-*` non-zero exit is a warning, not a rollback — the archive remains committed.

8. Report:

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
