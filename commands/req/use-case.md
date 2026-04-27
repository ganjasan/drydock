---
description: Write a Wiegers/Cockburn use case
argument-hint: "<UC-title>"
allowed-tools: Bash, Read, Write, SlashCommand
---

Thin wrapper that invokes the `use-case` skill and places the output at `<repo-root>/requirements/use-cases/UC-NNN_<slug>.md` with auto-numbering.

## Procedure

1. Load merged Drydock config (`source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load`). Resolve target directory: `<repo-root>/$(cfg_get paths.requirements)/$(cfg_get paths.requirements_subdirs.use_cases)/` (defaults `requirements/use-cases/`).

2. Auto-number: scan the directory for files matching `UC-[0-9][0-9][0-9]_*.md`, pick the next number. If the directory does not exist, ask before creating it.

3. Invoke the `use-case` skill with `$ARGUMENTS` as the title.

4. Wrap output with frontmatter:

   ```yaml
   ---
   id: UC-NNN
   title: "<title>"
   status: draft
   created: <YYYY-MM-DD>
   primary_actor: "<role from stakeholders/>"
   stakeholders: []
   traces_to:
     requirements: []
     epic: ""        # GitHub issue ref, e.g. "<owner>/<repo>#<N>", optional
   related: []
   ---
   ```

5. Save to `requirements/use-cases/UC-NNN_<slug>.md`. Use `lib/frontmatter.sh::fm_slug` for the slug.

6. Suggest next: `/dd:req:review` to validate against Wiegers criteria.

## Guardrails

- Do not create the use-cases directory silently if it does not exist.
- Auto-numbering is per-repo; do not consult any external numbering source.
