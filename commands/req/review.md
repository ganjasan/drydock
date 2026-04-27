---
description: Run a Wiegers requirements review on a file or folder
argument-hint: "<file-or-folder>"
allowed-tools: Bash, Read, SlashCommand
---

Thin wrapper that delegates to the `requirements-review` skill, scoped to a specific file or whole folder under `<repo-root>/requirements/`.

## Procedure

1. Resolve `$ARGUMENTS` against the repo root. Accept either:
   - a single Markdown file (review only that one)
   - a folder (iterate over all `*.md` excluding `README.md`, `INDEX.md`)

2. Invoke the `requirements-review` skill with the resolved scope.

3. The skill produces a per-file report keyed to the eight Wiegers quality criteria (clear, complete, consistent, feasible, necessary, prioritized, testable, unambiguous).

4. After the report:
   - Offer to apply trivial fixes in-place (e.g., add a missing priority tag) with explicit confirmation per file.
   - Leave non-trivial findings for the user.

5. If a file passes all eight criteria, offer to bump its `status:` frontmatter to `analyzed` (or `approved` if already analyzed).

## Guardrails

- Never auto-rewrite prose or restructure documents — only metadata-level fixes are eligible for auto-application.
- Never silently change `status:` — always confirm.
- The output report MUST cite each finding to a Wiegers criterion. This is what distinguishes the review from generic doc feedback.
