# Drydock

> A disciplined, AI-first development loop for Claude Code — from requirement to release.

Drydock is a Claude Code plugin and methodology that turns "vibe coding" into a repeatable craft:

- **Requirements** grounded in Karl Wiegers — vision & scope, stakeholders, use cases, ADRs, review.
- **Build loop** powered by OpenSpec — explore, design, apply, test.
- **Ship pipeline** — PR → archive → release, with traceability kept end-to-end.
- **Universal** — no ties to a particular SaaS, company, or domain.

The plugin ships a set of `/dd:*` commands, a library of skills and templates, and this repository is itself developed using Drydock (dogfooding).

## Status

Early. v0.1 in progress. See [requirements/vision/vision-and-scope.md](requirements/vision/vision-and-scope.md).

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

- [docs/methodology.md](docs/methodology.md) — the *why*: Wiegers + OpenSpec + Claude Code.
- [docs/workflow.md](docs/workflow.md) — the *what*: the concrete idea→merge loop.
- [docs/skills-catalog.md](docs/skills-catalog.md) — the skill library and when to invoke each.
- [docs/migration-from-apz.md](docs/migration-from-apz.md) — for users coming from the internal APZ plugin.

## Origin

Drydock is a universal descendant of APZ — the personal Claude Code plugin used internally at Apilize for requirements, build, and ship workflows. See [ADR-0001](requirements/adr/0001-name-drydock.md) for the naming decision.

## Quick look

```
drydock/
├── plugin.json            # Plugin manifest (auto-discovered by Claude Code)
├── config.yaml.example    # Template for project-specific configuration
├── commands/              # /dd:status, /dd:next, /dd:req:*, /dd:build:*, /dd:ship:*, /dd:plan:*
├── agents/                # Subagents invoked by commands (code-*, traces-linter, release-coordinator)
├── skills/                # Reusable skills (vision-and-scope, use-case, openspec-*, ...)
├── lib/                   # Small shell helpers (config loader, frontmatter helpers)
├── templates/             # Document templates (Wiegers, ADR, OpenSpec delta)
├── requirements/          # Drydock's OWN requirements — dogfood
│   ├── vision/
│   ├── adr/
│   ├── stakeholders/
│   └── use-cases/
├── openspec/              # Drydock's OWN OpenSpec changes — dogfood
└── docs/                  # Methodology, workflow, skills catalog, migration
```

## License

MIT (pending — see [LICENSE](LICENSE)).

## Contributing

Too early for external contributions. Stars and watches welcome; feedback via Issues.
