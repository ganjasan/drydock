# Skills Catalog

Shipwright ships (pun intended) a small, curated set of skills. Each skill is reusable across commands and can also be invoked directly.

Skills follow the Claude Code Skill convention: a `SKILL.md` with YAML frontmatter (`name`, `description`, triggering heuristics) and an optional `templates/` and `examples/` directory.

## Requirements skills

### vision-and-scope

Create a Wiegers-style Vision & Scope document. Invoked by `/sw:req:vision`.

### use-case

Write a Wiegers/Cockburn use case (primary actor, trigger, main success scenario, extensions, etc.). Invoked by `/sw:req:use-case`.

### stakeholder-profile

Create detailed stakeholder profiles. Invoked by `/sw:req:stakeholder`.

### requirements-elicitation

Prepare an elicitation plan — stakeholders, techniques, scheduling. Invoked by `/sw:req:elicit`.

### requirements-review

Review requirements against Wiegers quality criteria (clear, complete, consistent, feasible, necessary, prioritized, testable, unambiguous). Invoked by `/sw:req:review`.

### adr

Create an Architectural Decision Record with auto-numbering and traceability frontmatter. Invoked by `/sw:req:adr`.

## Build skills

### openspec-new-change

Create a new OpenSpec change with proposal/design/tasks skeleton. Invoked by `/sw:build:start`.

### openspec-continue-change

Advance a change to the next artifact. Invoked by `/sw:build:continue`.

### openspec-apply-change

Work through the tasks list of an active change. Invoked by `/sw:build:code`.

### openspec-ff-change

Fast-forward mode — generate all change artifacts in one pass for well-understood work. Invoked by `/sw:build:ff`.

### openspec-explore

Q&A mode for ambiguous scope. Invoked by `/sw:build:explore`.

### openspec-verify-change

Pre-archive verification: code matches the change, tasks all checked, specs deltas consistent. Invoked by `/sw:build:verify`.

## Ship skills

### openspec-archive-change

Archive a completed change after merge. Invoked by `/sw:ship:archive`.

### openspec-sync-specs

Sync deltas from a change into main specs. Invoked by `/sw:ship:sync` (also called by archive).

### openspec-bulk-archive

Archive multiple parallel completed changes in one pass. Invoked by `/sw:ship:bulk-archive`.

## Sub-agents (not skills, but related)

Sub-agents are autonomous helpers invoked by commands and skills — they handle focused tasks in parallel or in isolation:

- **code-reviewer** — reviews diffs for bugs, security, and project conventions.
- **code-explorer** — traces execution paths and maps architecture layers.
- **code-architect** — designs feature architectures from codebase patterns.
- **traces-linter** — verifies `traces_to` frontmatter references are bidirectional.
- **release-coordinator** — orchestrates multi-repo releases.
- **raw-classifier** — classifies raw client/signal artifacts into categories.

See `agents/` for the full list and individual descriptions.

## Conventions

- Skill directories are kebab-case under `skills/`.
- Each skill has a `SKILL.md` with `name`, `description`, `allowed-tools` (if restrictive), and the body of the skill prompt.
- Templates live in `skill-name/templates/`, examples in `skill-name/examples/`.
- Skills should be **invokable standalone** (without a command wrapper) — command files are thin wrappers that pass arguments and handle placement conventions.
