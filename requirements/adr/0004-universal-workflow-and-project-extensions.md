---
title: "ADR-0004: Universal workflow and project-local extensions"
status: accepted
date: 2026-04-27
deciders: Artem Konuchov
supersedes: ["0003-raw-conformance-parity-stay-in-apz"]
superseded_by: []
traces_to:
  vision: "requirements/vision/vision-and-scope.md"
  related:
    - "requirements/adr/0001-name-drydock.md"
    - "requirements/adr/0002-dogfooding-as-principle.md"
    - "requirements/adr/0003-raw-conformance-parity-stay-in-apz.md"
---

# ADR-0004: Universal workflow and project-local extensions

## Status

Accepted — 2026-04-27. Supersedes ADR-0003. Targets Drydock v0.2.

## Context

ADR-0003 (2026-04-27, the same day) drew a line: raw ingestion, conformance, and parity stay in the internal APZ plugin; Drydock provides only requirements/build/ship. That decision was made under the assumption that APZ would continue to live as a thin Apilize-specific layer above Drydock.

Reframing by the project owner shortly after ADR-0003 changed two premises:

1. **The workflow itself is universal.** The full loop is `raw → requirements → plan → build → ship`, not just `requirements → build → ship`. Capturing external signals (meetings, client emails, calendar events, Notion pages, Linear issues, GitHub issues from upstream repos) is the **left edge** of the loop in *every* project the owner runs, not an Apilize specialty. ADR-0003 placed `raw` on the wrong side of the universal/specific boundary.

2. **APZ is being retired entirely.** The owner does not want two plugins to maintain. Drydock becomes the only Claude Code plugin used across all projects (Apilize, FASTSAAS, future projects). Any project-specific behavior must therefore be expressible **inside the consuming repo**, not in a separate plugin.

These two changes together demand a different architecture from what ADR-0003 anticipated: Drydock must (a) cover the full pentaphase workflow as universal commands, and (b) expose well-defined extension points so each consuming repo can plug in its own specifics — sources, gates, hooks, paths, routing — without forking Drydock and without a sister plugin.

What stays project-specific in this model is the **content** of those extension points (Gmail filters, Notion DB IDs, Linear teams, conformance test runners, parity checks, public/private guards, area-to-repo maps), not the mechanism.

## Decision

### 1. Universal workflow is five phases

Drydock v0.2 covers `raw → requirements → plan → build → ship`. Concretely:

- **`/dd:raw:*`** — `capture`, `process`, `ingest-gmail`, `ingest-calendar`, `ingest-drive`, `ingest-notion`, `ingest-linear`, `ingest-github`, `transcribe`. Universal commands; sources and filters are config-driven.
- **`/dd:req:*`** — unchanged from v0.1.
- **`/dd:plan:*`** — unchanged from v0.1; area routing becomes config-driven.
- **`/dd:build:*`** — unchanged from v0.1.
- **`/dd:ship:*`** — `pr`, `archive`, `release` unchanged in surface; `release` gains a configurable gate list.

The raw-content directory layout (`raw/_incoming/`, `raw/meetings/`, `raw/feedback/`, `raw/ideas/`, `raw/competitors/`, `raw/client-boards/`) becomes a Drydock convention, with the root path overridable via config.

### 2. Three extension mechanisms, all repo-local

Project specifics live inside each consuming repo at three well-known locations:

```
<repo>/
├── .drydock/
│   ├── config.yaml          # project-specific configuration
│   └── hooks/               # lifecycle scripts invoked by Drydock commands
│       ├── pre-pr.sh
│       ├── pre-release.sh
│       ├── post-capture.sh
│       └── ...
└── .claude/
    └── commands/            # Claude Code-native project-local commands
        ├── conformance.md   # invoked as /conformance
        └── parity.md        # invoked as /parity
```

- **`.drydock/config.yaml`** — declarative configuration. Schema covers: paths, raw sources and filters, area routing, release gates, multi-repo coordination, GitHub Project IDs, worktree conventions, frontmatter rules. Replaces the current `${CLAUDE_PLUGIN_ROOT}/config.yaml` lookup, which was wrong for per-project config. (The plugin-root config remains as a global default fallback.)
- **`.drydock/hooks/`** — shell scripts invoked at well-defined lifecycle points. Drydock calls each by convention (`pre-pr.sh` before PR creation, `pre-release.sh` before tag, `post-capture.sh` after a raw signal lands, etc.). Non-zero exit aborts the operation. Absent file = skip.
- **`.claude/commands/`** — Claude Code's native per-project command directory. Drydock does **not** invent its own dispatcher; it references these commands by their slash-name in `config.yaml` (e.g. `release.gates: [/dd:build:test, /conformance, /parity]`).

This three-pronged model maps cleanly to the kinds of extensions seen in practice: declarative configuration, imperative scripted hooks, and full-blown project-specific commands.

### 3. APZ is fully retired

Following this ADR:

- Every APZ command has a Drydock equivalent (universal core) or migrates to repo-local extensions (project specifics).
- Apilize-Protocol conformance and parity become `<repo>/.claude/commands/conformance.md` and `parity.md` in `apilize-protocol/` (or wherever the test harness lives), referenced from `release.gates` in that repo's `.drydock/config.yaml`.
- `frontmatter-lint.sh` and `public-ready-guard.sh` become `apilize-hub/.drydock/hooks/post-capture.sh` and `pre-pr.sh`.
- Multi-repo area routing (Area label → `apilize-models|protocol|platform|...`) lives in `apilize-hub/.drydock/config.yaml` under `area_to_repo`.
- Gmail/Calendar/Notion/Linear filter sets live in the same config.

There is **no APZ plugin** after the migration. The `apilize-hub/plugins/apz/` directory is removed; its skill/agent contents either move into Drydock (universal) or into `apilize-hub/.drydock/` (project-local).

## Consequences

**Positive:**

- One plugin to install, version, and document. New projects start with `drydock` and a copy of `config.yaml.example`; they're productive immediately.
- The `raw` phase, which is in active daily use across the owner's projects, finally has a documented universal home.
- The extension model is honest: configuration is declarative, hooks are imperative, project commands are first-class. No abstract `SignalSource` interface that nobody implements.
- Project-local artifacts live next to project-local code, in version control, reviewable in PRs. No cross-repo plugin coordination.
- The `docs/migration-from-apz.md` mapping gets simpler — every APZ command has a destination, no "stays in APZ" footnotes.

**Negative / mitigations:**

- v0.2 is a meaningful jump in surface area from v0.1. The full `raw` namespace alone is nine commands. Mitigation: each of the four ADR-aligned changes (raw, config, hooks, retirement) lands as its own OpenSpec change with its own task list.
- ADR-0003 was accepted earlier the same day. Superseding within hours is unusual but warranted: the premise (APZ continuing as a layer) was invalidated by the owner's clarification, not by a code-level discovery. ADR-0003 remains in the record so the reasoning chain is auditable.
- Lifecycle hook conventions (`pre-pr.sh`, `pre-release.sh`, `post-capture.sh`, etc.) become a stability surface — renaming them later breaks consumer repos. Mitigation: ship a small, well-named set in v0.2, document each, and treat additions as the only allowed change in v0.x.
- Project-local commands referenced by `release.gates` rely on Claude Code's per-project `.claude/commands/` discovery. If Claude Code changes that mechanism, the contract breaks. Mitigation: depend only on the documented public interface; document the contract in `docs/extension-model.md`.

**Neutral:**

- The `agents/raw-classifier` agent, which ADR-0003 left in APZ, moves into Drydock alongside `/dd:raw:process`. Drydock's `agents/README.md` is updated accordingly.
- `${CLAUDE_PLUGIN_ROOT}/config.yaml` keeps working as a global default but becomes secondary to `<repo>/.drydock/config.yaml` (per-repo overrides win). Existing v0.1 installs continue working unchanged.

## Implementation plan

This ADR is realized through four OpenSpec changes, in order:

1. **`drydock-extension-model`** — define `<repo>/.drydock/config.yaml` schema, hook lifecycle points, command-reference contract; thread config-loading through existing commands; document in `docs/extension-model.md`.
2. **`add-raw-phase`** — port `/apz:raw:*` into `/dd:raw:*`; move the `raw-classifier` agent; generalize Apilize-specific defaults into config keys; update vision/methodology/workflow docs.
3. **`config-driven-paths-and-gates`** — remove remaining hardcoded paths; add `release.gates` orchestration; add `area_to_repo` resolution to `/dd:plan:promote` and `/dd:build:start`.
4. **`retire-apz`** *(in the Apilize-hub repo, not Drydock)* — delete `apilize-hub/plugins/apz/`; create `apilize-hub/.drydock/config.yaml` with Apilize defaults; move hooks; create `<repo>/.claude/commands/conformance.md` and `parity.md` in `apilize-protocol/`; update `apilize-hub/CLAUDE.md`.

Each change traces back to this ADR via frontmatter.

## Follow-ups

- [ ] Open OpenSpec change `drydock-extension-model` (step 1).
- [ ] Update `requirements/vision/vision-and-scope.md` v0.2 section (Section 3.2 "Scope of Subsequent Releases") to reflect the four-change plan and the pentaphase workflow.
- [ ] Update `docs/methodology.md` and `docs/workflow.md` to describe five phases instead of three.
- [ ] Update `docs/migration-from-apz.md` to reflect full retirement (no "stays in APZ" rows).
- [ ] Update ADR-0003 `superseded_by` field to point at this ADR.

## Related

- [ADR-0001](0001-name-drydock.md) — name decision.
- [ADR-0002](0002-dogfooding-as-principle.md) — dogfooding principle (relevant: Drydock evolves through its own workflow).
- [ADR-0003](0003-raw-conformance-parity-stay-in-apz.md) — superseded by this ADR.
- [`docs/migration-from-apz.md`](../../docs/migration-from-apz.md) — to be rewritten as part of the `retire-apz` change.
