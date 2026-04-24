# Shipwright — Agent Instructions

You are working inside the Shipwright repository. Shipwright is a Claude Code plugin and methodology for disciplined, AI-first software development: requirements → build → ship.

## Dogfooding principle

**Shipwright uses Shipwright.** Every change to this repository follows the same workflow Shipwright itself teaches:

1. Capture intent as requirements (`requirements/` — vision, ADRs, use cases).
2. Create an OpenSpec change under `openspec/changes/` before editing code.
3. Apply the change, then archive it, syncing deltas into `openspec/specs/`.
4. Ship via PR with traceability links back to the change and requirement.

When in doubt, prefer structure over speed — the project is its own test suite for the methodology.

## Language

- **Agent-facing documentation** (this file, commands, skill descriptions, ADR bodies) — **English**.
- **Requirements documents** (vision & scope, use cases, stakeholder profiles) — may be Russian or English; follow the author's choice per document.
- **Code identifiers and technical terms** — original language, always.

## Structure

```
shipwright/
├── commands/       # /sw:req:*, /sw:build:*, /sw:ship:*, /sw:plan:* command files
├── agents/         # Subagents invoked by commands
├── skills/         # Reusable skills with optional templates/ and examples/
├── templates/      # Top-level templates shared across commands/skills
├── requirements/   # Shipwright's own requirements (dogfood)
├── openspec/       # Shipwright's own OpenSpec changes and specs (dogfood)
└── docs/           # Methodology, workflow, catalog
```

## Naming conventions

- Commands: kebab-case Markdown files, grouped in `commands/<phase>/<action>.md`.
- Agents: kebab-case (`plugin-dev:code-reviewer` style), one YAML frontmatter + prompt.
- Skills: kebab-case directories under `skills/`, each with a `SKILL.md`.
- ADRs: `requirements/adr/NNNN-kebab-title.md` with sequential numbering.
- OpenSpec changes: `openspec/changes/YYYY-MM-DD-kebab-title/`.

## Do not

- Do not add ties to a specific SaaS, company, or domain — Shipwright is universal. Domain specifics belong in consumer projects.
- Do not introduce backward-compatibility shims for APZ command names. A one-time migration guide lives in `docs/migration-from-apz.md`.
- Do not auto-push or auto-release. Releases are explicit and gated by the ship pipeline.

## When starting work

1. Read `docs/methodology.md` and `docs/workflow.md` for context.
2. Check `openspec/changes/` for any work-in-progress before starting a new change.
3. For any non-trivial change, create an OpenSpec change first, then apply.
