---
title: "ADR-0003: Raw ingestion, conformance, and parity stay in APZ"
status: accepted
date: 2026-04-27
deciders: Artem Konuchov
supersedes: []
superseded_by: []
traces_to:
  vision: "requirements/vision/vision-and-scope.md"
  change: "openspec/changes/port-apz-commands"
  related: []
---

# ADR-0003: Raw ingestion, conformance, and parity stay in APZ

## Status

Accepted — 2026-04-27. Recorded as part of the `port-apz-commands` OpenSpec change.

## Context

The port from APZ to Drydock had to draw a line between two sets of capabilities:

1. **Universal** capabilities that apply to any disciplined development project (requirements via Wiegers, OpenSpec change loop, GitHub-issue planning, generic release pipeline).
2. **Project-specific** capabilities that depend on artifacts, directory layouts, or external integrations specific to one organization's setup.

Three APZ feature groups stood out as project-specific:

- **Raw ingestion** (`/apz:raw:*`) — pulls from Gmail, Calendar, Drive, Notion, Linear, GitHub, and a meeting transcription pipeline; classifies into a fixed inbox layout under `apilize-hub/raw/_incoming/`. The directory shape, filter set, and downstream `/apz:raw:process` flow are all built around the Apilize hub's structure.
- **Conformance** (`/apz:ship:conformance`) — runs Apilize Protocol conformance tests against a model container. The test runner, fixture format, and pass criteria are Apilize-Protocol-specific.
- **Parity** (`/apz:ship:parity`) — validates numerical parity between a new Apilize-protocol model and its legacy counterpart. Defined in terms of Apilize model semantics.

The decision was whether to:

1. Pull these into Drydock with generalized abstractions (e.g. a "signal capture" interface, a "release gate plugin" interface), or
2. Keep them in APZ as the layer that consumes Drydock and adds Apilize-specific commands on top.

## Options considered

### Option A: Generalize and lift into Drydock

Define abstract interfaces (`SignalSource`, `ReleaseGate`) so any consumer could plug in their own Gmail/Notion/Linear adapter or their own conformance harness.

- Pros: maximum reuse; one codebase across organizations; surface area visible from the start.
- Cons: the abstractions are speculative — no second consumer exists yet, and Wiegers' "necessary" criterion (and YAGNI in general) argues against premature interface design. Each integration also brings auth/transport concerns (OAuth scopes, MCP server lifecycles) that are non-trivial to make universal. Significant complexity for the v0.1 milestone.

### Option B: Keep raw / conformance / parity in APZ; Drydock stays focused

APZ continues to ship these commands and the supporting hub directory layout. Drydock provides the universal core (requirements, build, ship-pr, plan, release-no-gates).

- Pros: Drydock v0.1 ships small and complete on its own scope. APZ's project-specific surface remains where it has been working. No premature abstraction. A second consumer that needs raw ingestion will produce a real second data point to inform any future generalization.
- Cons: APZ users coming to Drydock alone won't find raw ingestion or the protocol-specific gates. Mitigated by: those users either bring their own equivalent integrations or accept that raw ingestion is out of scope for now.

### Option C: Skeleton in Drydock with Apilize implementation in APZ

Ship empty `/dd:raw:*`, `/dd:ship:conformance`, `/dd:ship:parity` files in Drydock that print "configure a backend" and let APZ overload them.

- Pros: namespace reservation; minimal Drydock surface.
- Cons: empty commands clutter the help listing without delivering value. Reservation is unnecessary because Claude Code plugins can add commands without conflict — APZ's commands stay under `/apz:*`, no collision.

## Decision

**Option B.** Drydock v0.1 does not include raw ingestion, conformance, or parity. APZ retains these commands and continues to operate against the `apilize-hub/raw/_incoming/` layout and the Apilize Protocol fixtures.

This decision is recorded explicitly because:

- The `port-apz-commands` change deliberately excludes these capabilities.
- Anyone reading Drydock's command surface and wondering "why isn't there a `/dd:raw:capture`?" deserves a written answer.
- A future change may revisit Option A once a second project demonstrates concrete need; this ADR's `superseded_by` field will record that.

## Consequences

**Positive:**

- Drydock v0.1 has a coherent, narrowly-scoped command suite — easier to document, test, and explain.
- APZ remains a working plugin for Apilize without disruption.
- The "no ties to a specific SaaS, company, or domain" rule in `CLAUDE.md` is preserved without contortion.

**Negative / mitigations:**

- External users adopting Drydock who want raw-content ingestion must roll their own (or use a third-party tool). Mitigation: this ADR and `docs/migration-from-apz.md` make the boundary explicit so users plan accordingly.
- Future generalization (Option A) carries some refactoring cost. Mitigation: Drydock's plugin architecture means new commands can be added by a layer plugin without modifying Drydock — APZ is itself the prototype of that pattern.

**Neutral:**

- The `agents/raw-classifier` agent stays in APZ, mirroring the command exclusion. `agents/README.md` calls this out.

## Follow-ups

- [ ] When a second project (besides Apilize) needs raw ingestion, record the use case and revisit Option A.
- [ ] Document the boundary in `docs/migration-from-apz.md` (already linked from this ADR via the `change:` trace).

## Related

- [`docs/migration-from-apz.md`](../../docs/migration-from-apz.md) — section "What stays in APZ".
- [`openspec/changes/port-apz-commands/proposal.md`](../../openspec/changes/port-apz-commands/proposal.md) — original scope decision.
