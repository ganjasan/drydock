# Drydock

> A disciplined, AI-first development loop for Claude Code — from external signal to release.

Drydock is a Claude Code plugin and methodology that turns "vibe coding" into a repeatable craft. The full loop is **`Raw → Requirements → Plan → Build → Ship`** (pentaphase workflow from v0.2 — see [ADR-0004](requirements/adr/0004-universal-workflow-and-project-extensions.md)):

- **Raw** *(v0.2)* — capture external signals (gmail, calendar, drive, notion, linear, github, manual notes) into a structured inbox.
- **Requirements** grounded in Karl Wiegers — vision & scope, stakeholders, use cases, ADRs, review.
- **Plan** — backlog as GitHub issues with triage, area routing, and promotion to OpenSpec changes.
- **Build loop** powered by OpenSpec — explore, design, apply, test, verify.
- **Ship pipeline** — PR → archive → release, with configurable gates and traceability kept end-to-end.

The plugin ships a set of `/dd:*` commands, a library of skills and templates, and this repository is itself developed using Drydock (dogfooding).

**One plugin, all projects.** Project-specific behavior (Gmail filters, area-to-repo routing, release gates, content guards) lives inside the consuming repo at `<repo>/.drydock/config.yaml`, `<repo>/.drydock/hooks/`, and `<repo>/.claude/commands/`. The plugin code itself is universal — no ties to any organization. See [docs/extension-model.md](docs/extension-model.md).

## Status

Early. v0.1 shipped (req/plan/build/ship). v0.2 in progress: pentaphase workflow + extension model + APZ retirement (4 OpenSpec changes — see [ADR-0004](requirements/adr/0004-universal-workflow-and-project-extensions.md) and [requirements/vision/vision-and-scope.md](requirements/vision/vision-and-scope.md) §3.2).

## Install

Drydock is a Claude Code plugin. To install:

1. Clone this repo somewhere on your machine, or vendor it under your own dotfiles.
2. Add the path to your Claude Code plugin search list (typically `~/.claude/plugins/` or via `settings.json`).
3. Reload Claude Code; the plugin auto-discovers `commands/`, `skills/`, and `agents/` from the manifest.

Verify the install by running:

```
/dd:status
```

This is the first command to learn — it reports your current location in the workflow (repo, branch, active OpenSpec change, open PRs) and works without any configuration.

For project-specific tuning (GitHub Project ID, area→repo routing, worktree conventions), copy `config.yaml.example` to `config.yaml` next to it and adjust the keys you care about. All keys are optional; built-in defaults are universal.

## Methodology and workflow

- [docs/methodology.md](docs/methodology.md) — the *why*: Wiegers + OpenSpec + Claude Code, the five phases.
- [docs/workflow.md](docs/workflow.md) — the *what*: the concrete signal→merge→release loop.
- [docs/skills-catalog.md](docs/skills-catalog.md) — the skill library and when to invoke each.
- [docs/extension-model.md](docs/extension-model.md) — config schema, hook lifecycle, project-local commands.
- [docs/migration-from-apz.md](docs/migration-from-apz.md) — for users moving off the now-retired APZ plugin.

## Origin

Drydock is a universal descendant of APZ — the personal Claude Code plugin used internally at Apilize for requirements, build, and ship workflows. See [ADR-0001](requirements/adr/0001-name-drydock.md) for the naming decision.

## Quick look

```
drydock/
├── .claude-plugin/        # Plugin manifest (auto-discovered by Claude Code)
├── config.yaml.example    # Template for global plugin defaults
├── commands/              # /dd:status, /dd:next, /dd:raw:* (v0.2), /dd:req:*, /dd:plan:*, /dd:build:*, /dd:ship:*
├── agents/                # Subagents invoked by commands (code-*, traces-linter, release-coordinator, raw-classifier in v0.2)
├── skills/                # Reusable skills (vision-and-scope, use-case, openspec-*, ...)
├── lib/                   # Small shell helpers (config loader, frontmatter helpers)
├── templates/             # Document templates (Wiegers, ADR, OpenSpec delta)
├── requirements/          # Drydock's OWN requirements — dogfood
│   ├── vision/
│   ├── adr/
│   ├── stakeholders/
│   └── use-cases/
├── openspec/              # Drydock's OWN OpenSpec changes — dogfood
└── docs/                  # Methodology, workflow, skills catalog, extension model, migration
```

## License

MIT (pending — see [LICENSE](LICENSE)).

## Contributing

Too early for external contributions. Stars and watches welcome; feedback via Issues.
