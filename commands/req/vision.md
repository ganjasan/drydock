---
description: Create or update a Vision and Scope document (Wiegers form)
argument-hint: "[<scope-name>]"
allowed-tools: Bash, Read, Write, SlashCommand
---

Thin wrapper that delegates to the `vision-and-scope` skill, places the output under `<repo-root>/requirements/vision/`.

## Procedure

1. Load Drydock config and the path resolver:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
   source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
   target_dir="$(dd_path requirements_subdir vision)"
   ```
   Defaults are `<repo>/requirements/vision/`; per-repo overrides via `paths.requirements` and `paths.requirements_subdirs.vision` in `<repo>/.drydock/config.yaml`.

2. Determine the target filename from `$ARGUMENTS`:
   - No argument → `vision-and-scope.md` (the project-level vision).
   - One argument `<scope-name>` → `<scope-name>-vision-and-scope.md` (allows multiple visions per repo when sub-projects/subsystems each need their own).

3. If the target file exists → ask the user whether to update (preserve sections not being modified) or replace.

4. Invoke the `vision-and-scope` skill (Skill tool with `skill: vision-and-scope`). Pass the user's intent as args.

5. Ensure the resulting document has frontmatter:

   ```yaml
   ---
   title: "<scope> Vision and Scope"
   version: "<semver>"
   created: <YYYY-MM-DD>
   updated: <YYYY-MM-DD>
   status: draft | review | approved | superseded
   ---
   ```

6. Save to the resolved path. Report the path and suggest `/dd:req:review <path>` to validate Wiegers criteria.

## Guardrails

- Do not create `requirements/vision/` silently if it does not exist; ask first.
- Never overwrite an existing approved document — bump version and mark superseded instead.
