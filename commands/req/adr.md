---
description: Create a new Architectural Decision Record with auto-numbering and traceability
argument-hint: "<short-title>"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, SlashCommand
---

Thin wrapper that delegates to the `adr` skill and resolves the target directory via Drydock configuration.

Argument: `$ARGUMENTS` — short title (e.g. "ingestion orchestration choice").

## Procedure

1. Resolve target directory via config (`paths.requirements` + `paths.requirements_subdirs.adr`; defaults `requirements/adr/`).

2. Invoke the `adr` skill with `$ARGUMENTS` as the title and the resolved directory as the target. The skill handles:
   - Auto-numbering (4-digit, locally scoped).
   - Interactive context gathering.
   - File template with frontmatter.
   - Optional resolution of open questions.

3. Optional: if `config.yaml` declares `github.adr_creates_issue: true`, after the file is written offer to create a GitHub discussion issue via `gh issue create` with title `[ADR] ADR-NNNN: <title>` and body containing Context + Options + Decision (without the template boilerplate). Default is **no issue** — ADRs are local artifacts.

4. Report the path and next-step suggestion (discuss, then update `status:` to `accepted` via PR review).

## Guardrails

- Auto-numbering is **local to the current repo's** ADR directory only. Do not consult any external counter.
- Status is always `proposed` on creation. Accepting is a human decision via review.
- Never modify an existing ADR file; create a new ADR with `supersedes: [<old-NNNN>]` instead.
