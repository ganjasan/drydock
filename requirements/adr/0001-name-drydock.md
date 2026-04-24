---
title: "ADR-0001: Name — Drydock"
status: accepted
date: 2026-04-24
deciders: Artem Konuchov
traces_to:
  vision: "requirements/vision/vision-and-scope.md"
---

# ADR-0001: Name — Drydock

## Status

Accepted — 2026-04-24. Supersedes the tentative working name "Shipwright" (see below).

## Context

The internal Claude Code plugin **APZ** (Apilize-scoped) proved its methodology on several internal projects. The decision was made to extract the universal core into a standalone project, to be published as opensource and used by other consumers (starting with FASTSAAS).

A new name is required that:

1. Is **universal** — no ties to Apilize or any specific domain.
2. Rhymes with the workflow verbs already baked into the plugin: `req`, `build`, **`ship`**.
3. Is short enough to type as a command prefix (`/<name>:`).
4. Is available on GitHub, npm, and PyPI namespaces.
5. Is searchable without major collisions with other software.
6. Conveys craft and discipline rather than speed alone — the plugin's value proposition is structure, not velocity.

The initial working name was **Shipwright**, chosen for its clear alignment with `/ship:*` and the craft framing. During pre-publication due diligence a **hard collision** was found: [shipwright.io](https://shipwright.io) is an established CNCF sandbox project (Red Hat) for building container images with Kubernetes. The name is well-indexed in the cloud-native ecosystem and would cause persistent search confusion for an unrelated AI-workflow tool.

## Options considered

| Name          | Pros                                                                  | Cons                                                                     |
|---------------|-----------------------------------------------------------------------|--------------------------------------------------------------------------|
| Shipwright    | Ship-builder metaphor, craft emphasis                                 | **Hard collision with shipwright.io (CNCF, Red Hat) — disqualifying**   |
| Shipwright-CC | Resolves collision via suffix                                         | Compound name feels like a workaround, not a brand                       |
| **Drydock**   | Ship metaphor retained — the place where a ship is built, repaired, and prepared for launch; short; available; distinctive | Slightly less personal than "wright"; two-word concept compressed        |
| Slipway       | Unique ship-launching metaphor; available                             | Less recognizable English word; weaker connection to ongoing craft       |
| Coxswain      | Unique (boat steering); craft emphasis                                | Obscure spelling; hard to type                                           |
| Cairn         | Short, trail-marker metaphor; available                               | Breaks the ship-metaphor continuity with `/ship:*`                       |
| Forge / Foundry / Anvil | Craft metaphors                                             | Heavy collisions across dev-tool ecosystems                              |
| Cadence       | Rhythm of dev work                                                    | Collision with Uber's Cadence Workflow                                   |

## Decision

**Drydock.**

Rationale:

- A drydock is the structured environment where a ship is built, overhauled, and prepared for launch. This is exactly what Drydock does for software projects — it is the disciplined workspace, not the launch itself. The name reinforces the methodology's emphasis on preparation and structure.
- The ship metaphor is retained and continues to align with `/ship:*` as the terminal phase of the workflow: projects come out of the drydock to ship.
- No known collision in the opensource landscape as of April 2026 (verified: `github.com/ganjasan/drydock` is available; broader `drydock` namespaces — TBD at publication).
- Short enough to type. Canonical command prefix: `dd:` (`/dd:req:vision`, `/dd:build:start`, `/dd:ship:pr`). Long form `drydock:` remains valid.

## Consequences

**Positive:**

- Clear, distinctive brand with no immediate name collision.
- Natural alignment with existing `ship:*` vocabulary: *the drydock prepares what the `ship` pipeline releases*.
- The metaphor is honest about what the plugin does — it is not a generator, it is a workspace for careful building.

**Negative / mitigations:**

- "Drydock" is slightly less evocative of a person (as "wright" was) and more of a place. Acceptable trade-off: the plugin is in fact a place (a set of conventions and tools), not a person.
- Command prefix `dd:` collides with the unix `dd` command mnemonic, but only in brand-association terms — there is no actual command conflict. Mitigation: documentation framing ("dd = drydock, not the copy tool").
- If someone grabs `drydock` on npm/PyPI/GitHub org level later, fall back to `drydock-cc` or `drydock-claude`. A rename would again cost only metadata; nothing in code ties to the name.

**Neutral:**

- The working name "Shipwright" was used in an unpublished local commit only; no external references exist.

## Follow-ups

- [ ] Verify availability of `drydock` on GitHub orgs (repo under user `ganjasan` is confirmed available), npm, PyPI at publication.
- [ ] Reserve `drydock.dev` or similar domain if cheap and available.
- [ ] Update `plugin.json` command prefix to `dd:` and verify command files use it consistently.
