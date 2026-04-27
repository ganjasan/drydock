---
description: Prepare a requirements elicitation plan (Wiegers form)
argument-hint: "[<project-context>]"
allowed-tools: Bash, Read, Write, SlashCommand
---

Thin wrapper that delegates to the `requirements-elicitation` skill. Produces an actionable, short plan: who to interview, what gaps to close, which techniques to use, and on what schedule.

## Procedure

1. Read available context from `<repo-root>/requirements/` — vision, stakeholders, existing use cases — so the elicitation plan is grounded in current state.

2. Invoke the `requirements-elicitation` skill with `$ARGUMENTS` as additional context (project type, deadline, team size — optional).

3. The skill performs gap analysis (compares existing artifacts against Wiegers' expected structure) and proposes elicitation techniques (interview / survey / observation / artifact analysis / prototyping / workshop) per gap.

4. Save the result to `requirements/elicitation/<YYYY-MM-DD>-elicitation-plan.md` with frontmatter:

   ```yaml
   ---
   created: <YYYY-MM-DD>
   analyst: "<name>"
   target_completion: "<YYYY-MM-DD>"
   status: draft | active | done
   ---
   ```

5. Report the saved path. Suggest follow-up commands as gaps close: `/dd:req:stakeholder`, `/dd:req:use-case`, `/dd:req:vision`.

## Guardrails

- Do not create `requirements/elicitation/` silently; ask first.
- Plan is a working document, not a corporate deliverable — keep it under two pages worth of content.
