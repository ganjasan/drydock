---
title: "ADR-0002: Dogfooding as a first-class principle"
status: accepted
date: 2026-04-24
deciders: Artem Konuchov
traces_to:
  vision: "requirements/vision/vision-and-scope.md"
  related_adr: "requirements/adr/0001-name-drydock.md"
---

# ADR-0002: Dogfooding as a first-class principle

## Status

Accepted — 2026-04-24.

## Context

Drydock is a methodology-as-code plugin: it teaches a disciplined Req → Build → Ship workflow. The fastest way for a methodology to become stale, incoherent, or detached from reality is to be developed **without** following itself.

APZ was developed organically — changes happened faster than the methodology was formalized. That was appropriate for an internal, single-user plugin. Drydock is being extracted as a standalone product with an external audience; the bar for coherence is higher.

## Decision

**Drydock is developed using Drydock.** Every non-trivial change to this repository goes through the same loop Drydock itself prescribes:

1. A business/user need is captured as a requirement artifact (`requirements/vision/`, `requirements/use-cases/`, `requirements/adr/`) before code changes.
2. An OpenSpec change is created under `openspec/changes/` before implementation.
3. Implementation follows the change's task list.
4. A PR links the change and the requirement(s) it satisfies.
5. On merge, the change is archived and deltas are synced into `openspec/specs/`.

"Trivial" changes that bypass this (typo fixes, dependency bumps, README polish) must be listed explicitly in `CLAUDE.md` and `docs/workflow.md` — the exception list is part of the methodology, not an ad-hoc escape.

## Consequences

**Positive:**

- The repository is a working example of the methodology — anyone can inspect `requirements/`, `openspec/`, and `CHANGELOG` to see how it all fits.
- Friction in the workflow surfaces immediately, at the earliest possible point.
- New skills, commands, and templates are validated against a real project (this one) before being released.

**Negative:**

- Overhead on every change. **Mitigation:** a clearly-scoped "trivial" exception list; `/dd:build:ff` fast-forward mode for small, well-understood changes.
- The repository's history will appear slower than typical OSS repos. **Mitigation:** the slowness *is* the demonstration — it's not a side-effect.

**Neutral:**

- External contributors must follow the same flow, which raises the contribution bar. This is acceptable for v0.x; a lighter "contributor mode" can be added in v1.x if demand appears.

## Follow-ups

- [ ] Draft the "trivial change" exception list in `docs/workflow.md`.
- [ ] Implement `/dd:build:ff` fast-forward command.
- [ ] Add a `CONTRIBUTING.md` referencing this ADR.
