---
description: Create a Wiegers stakeholder profile
argument-hint: "<name> [role]"
allowed-tools: Bash, Read, Write, SlashCommand
---

Thin wrapper that invokes the `stakeholder-profile` skill and places the output under the right category in `<repo-root>/requirements/stakeholders/`.

## Procedure

1. Load Drydock config and path resolver:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
   source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
   target_dir="$(dd_path requirements_subdir stakeholders)"
   ```
   Defaults `<repo>/requirements/stakeholders/`.

2. Ask the user (or infer from `$ARGUMENTS`) which category applies:
   - `users/` — direct users of the system
   - `customers/` — purchasing decision-makers (may differ from users)
   - `internal/` — internal team members (sponsor, ops, support)
   - `external/` — partners, vendors, regulators
   - `competitors/` — for intel only (separate from collaboration)

3. Invoke the `stakeholder-profile` skill with input from `$ARGUMENTS`.

4. Save the result to `requirements/stakeholders/<category>/<name-slug>.md` (slug via `lib/frontmatter.sh::fm_slug`). Ensure frontmatter:

   ```yaml
   ---
   created: <YYYY-MM-DD>
   role: "<role>"
   tags: [stakeholder, "category/<category>"]
   priority: "High | Medium | Low"   # Wiegers influence × interest scoring
   related: []
   ---
   ```

5. If `requirements/stakeholders/overview.md` exists → append a row to its stakeholder matrix. If not → ask before creating.

6. Report the saved path and suggest related next steps:
   - `/dd:req:use-case` if this stakeholder's needs imply specific scenarios
   - `/dd:req:vision` if they affect scope or vision

## Guardrails

- Do not create category subdirectories silently. Ask the first time each category is used.
- Never write contact details (phone, address) without explicit user input — Wiegers profiles are role-focused, not contact lists.
