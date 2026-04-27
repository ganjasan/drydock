# Drydock — Agent Instructions

You are working inside the Drydock repository. Drydock is a Claude Code plugin and methodology for disciplined, AI-first software development: `raw → requirements → plan → build → ship` (pentaphase workflow from v0.2; see [ADR-0004](requirements/adr/0004-universal-workflow-and-project-extensions.md)).

## Dogfooding principle

**Drydock uses Drydock.** Every change to this repository follows the same workflow Drydock itself teaches:

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
drydock/
├── commands/       # /dd:raw:* (v0.2), /dd:req:*, /dd:plan:*, /dd:build:*, /dd:ship:* command files
├── agents/         # Subagents invoked by commands (raw-classifier added in v0.2)
├── skills/         # Reusable skills with optional templates/ and examples/
├── lib/            # Small shell helpers (config loader, frontmatter helpers)
├── templates/      # Top-level templates shared across commands/skills
├── requirements/   # Drydock's own requirements (dogfood)
├── openspec/       # Drydock's own OpenSpec changes and specs (dogfood)
└── docs/           # Methodology, workflow, catalog, extension-model, migration
```

Project-specific behavior in *consuming* repos lives in:

```
<consumer-repo>/
├── .drydock/
│   ├── config.yaml          # paths, raw sources, area routing, release.gates
│   └── hooks/               # pre-pr.sh, pre-release.sh, post-capture.sh, ...
└── .claude/commands/        # project-local slash commands (e.g. /conformance, /parity)
```

Drydock plugin code itself never references a specific organization or domain — that's enforced by the "Do not" rules below.

## Naming conventions

- Commands: kebab-case Markdown files, grouped in `commands/<phase>/<action>.md`.
- Agents: kebab-case (`plugin-dev:code-reviewer` style), one YAML frontmatter + prompt.
- Skills: kebab-case directories under `skills/`, each with a `SKILL.md`.
- ADRs: `requirements/adr/NNNN-kebab-title.md` with sequential numbering.
- OpenSpec changes: `openspec/changes/YYYY-MM-DD-kebab-title/`.

## Do not

- Do not add ties to a specific SaaS, company, or domain — Drydock is universal. Domain specifics belong in the consumer repo's `.drydock/` and `.claude/commands/` directories. After v0.2 the plugin code must contain zero references to Apilize, WertXpert, INTREAL, or any other client/product name.
- Do not introduce backward-compatibility shims for APZ command names. APZ is being fully retired (see [ADR-0004](requirements/adr/0004-universal-workflow-and-project-extensions.md)); the one-time migration guide lives in `docs/migration-from-apz.md`.
- Do not introduce a sibling plugin for project specifics. There is one plugin (`drydock`); project specifics live in `<repo>/.drydock/` via the extension model.
- Do not auto-push or auto-release. Releases are explicit and gated by the ship pipeline.

## When starting work

1. Read `docs/methodology.md` and `docs/workflow.md` for context.
2. Check `openspec/changes/` for any work-in-progress before starting a new change.
3. For any non-trivial change, create an OpenSpec change first, then apply.
