# Shipwright

> A disciplined, AI-first development loop for Claude Code — from requirement to release.

Shipwright is a Claude Code plugin and methodology that turns «vibe coding» into a repeatable craft:

- **Requirements** grounded in Karl Wiegers — vision & scope, stakeholders, use cases, ADRs, review.
- **Build loop** powered by OpenSpec — explore, design, apply, test.
- **Ship pipeline** — PR → archive → release, with traceability kept end-to-end.
- **Universal** — no ties to a particular SaaS, company, or domain.

The plugin ships a set of `/sw:*` commands, a library of skills and templates, and this repository is itself developed using Shipwright (dogfooding).

## Status

Early. v0.1 in progress. See [requirements/vision/vision-and-scope.md](requirements/vision/vision-and-scope.md).

## Origin

Shipwright is a universal descendant of APZ — the personal Claude Code plugin used internally at Apilize for requirements, build, and ship workflows. See [ADR-0001](requirements/adr/0001-name-shipwright.md) for the naming decision.

## Quick look

```
shipwright/
├── commands/           # /sw:req:*, /sw:build:*, /sw:ship:*, /sw:plan:*
├── agents/             # Subagents invoked by commands
├── skills/             # Reusable skills (vision-and-scope, use-case, etc.)
├── templates/          # Document templates (Wiegers, ADR, OpenSpec delta)
├── requirements/       # Shipwright's OWN requirements — dogfood
│   ├── vision/
│   ├── adr/
│   ├── stakeholders/
│   └── use-cases/
├── openspec/           # Shipwright's OWN OpenSpec changes — dogfood
└── docs/               # Methodology, workflow, skills catalog
```

## License

MIT (pending — see [LICENSE](LICENSE)).

## Contributing

Too early for external contributions. Stars and watches welcome; feedback via Issues.
