---
title: "ADR-0001: Name — Shipwright"
status: accepted
date: 2026-04-24
deciders: Artem Konuchov
traces_to:
  vision: "requirements/vision/vision-and-scope.md"
---

# ADR-0001: Name — Shipwright

## Status

Accepted — 2026-04-24.

## Context

The internal Claude Code plugin **APZ** (Apilize-scoped) proved its methodology on several internal projects. A decision was made to extract the universal core into a standalone project, to be published as opensource and used by other consumers (starting with FASTSAAS).

A new name is required that:

1. Is **universal** — no ties to Apilize or any specific domain.
2. Rhymes with the workflow verbs already baked into the plugin: `req`, `build`, **`ship`**.
3. Is short enough to type as a command prefix (`/<name>:`).
4. Is available on GitHub, npm, and PyPI namespaces.
5. Is searchable without major collisions with other software.
6. Conveys craft and discipline rather than speed alone — the plugin's value proposition is structure, not velocity.

## Options considered

| Name          | Pros                                                                    | Cons                                                                              |
|---------------|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------|
| **Shipwright**| Ship-builder metaphor matches `/ship:*`; craft emphasis; short enough   | Slightly long as command prefix (mitigated by `sw`)                              |
| Forge         | Short, evocative (forging software)                                     | Heavy collision (GitForge, Forge CLI, many package names)                        |
| Foundry       | "Where things are made"                                                 | Used by Foundry VTT and several dev tools; likely collisions                     |
| Anvil         | Short, memorable                                                        | Anvil.works exists (Python web framework); brand confusion                       |
| Keel          | Backbone of a ship — foundation metaphor; very short                    | Keel.sh exists (Kubernetes-related)                                              |
| Slipway       | Unique to ship-launching; available                                     | Less recognizable English word; weaker connection to craft                       |
| Cadence       | Rhythm of dev work                                                      | Cadence Workflow (Uber OSS) — heavy naming collision                             |
| Atelier       | Craftsman workshop                                                      | French; less approachable; used by some design tools                             |
| SpecShip      | Literal (specs → ship)                                                  | Feels like a compound hack, not a brand                                          |

## Decision

**Shipwright.**

Rationale:

- The verb `ship` is already the terminal phase of the workflow (`/ship:*`). `Shipwright` positions the entire plugin as the craft of building things that ship.
- "Wright" is a historical English suffix for a skilled maker (*playwright*, *millwright*, *wheelwright*). It conveys discipline, specialization, and craft — the exact values Shipwright teaches.
- Available: no major opensource project named `shipwright` on npm/PyPI/GitHub as of April 2026 *(to be verified at publication)*.
- Short-form command prefix: `sw` (`/sw:req:vision`, `/sw:build:start`, `/sw:ship:pr`). Two-letter prefix is optimal for typing.
- No domain ties; universal.

## Consequences

**Positive:**

- Clear, memorable brand.
- Natural alignment with existing `ship:*` vocabulary.
- Craftsmanship framing reinforces the methodology's core value (structure over speed).

**Negative / mitigations:**

- `shipwright` is 10 characters — mitigated by accepting `sw:` as the canonical command prefix and reserving `shipwright:` as the long form (both valid).
- Risk of later collision if someone else takes `shipwright` on GitHub/npm between now and first publication. **Mitigation:** reserve repos and package names at publication time; if taken, fall back to `shipwright-cc` (Claude Code) or similar. A rename would cost only metadata; no code ties to the name exist yet.

**Neutral:**

- Command prefix is `sw:` by default. Users may alias to `shipwright:` if they prefer.

## Follow-ups

- [ ] Verify availability of `shipwright` on GitHub (user + orgs), npm, PyPI at publication.
- [ ] Reserve `shipwright.dev` domain if cheap and available.
- [ ] Decide canonical short prefix: `sw` vs. `ship`. **Tentative:** `sw`.
