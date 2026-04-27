# Methodology

Drydock turns AI-assisted development into a disciplined, traceable loop. It combines three well-established bodies of work and adds a minimal glue layer on top:

1. **Karl Wiegers' requirements engineering** — vision & scope, stakeholder profiles, use cases, ADRs, requirements review.
2. **OpenSpec** — changes-as-artifacts: each modification of behavior is described before it is implemented, with a tasks list and deltas that fold back into living specs.
3. **Claude Code** — as the execution environment (plugin, skills, agents, MCP).

The core claim of Drydock is simple: **the bottleneck in AI-assisted software development is not generation speed — it is coherence.** A Claude Code session that produces 500 lines of code in an hour is only valuable if those 500 lines are traceable to a requirement, reviewable against a spec, and safe to ship.

## Five phases

The full Drydock loop is `Raw → Requirements → Plan → Build → Ship`. Earlier versions of this document described only the right three phases; from v0.2 onward the left edge (raw signal capture) is a first-class part of the methodology — see [ADR-0004](../requirements/adr/0004-universal-workflow-and-project-extensions.md).

### 1. Raw (`/dd:raw:*`)

Capture external signals **before** they become requirements.

- **capture** — manually log a meeting note, client request, or idea into `raw/_incoming/` with structured frontmatter.
- **ingest-{gmail,calendar,drive,notion,linear,github}** — scheduled or on-demand pulls from external systems into the same inbox.
- **transcribe** — audio/video → text for meeting recordings.
- **process** — classify the inbox into `raw/meetings/`, `raw/feedback/`, `raw/ideas/`, `raw/competitors/`, `raw/client-boards/`; dedup; cross-link to existing requirements and issues; suggest backlog items.

The deliverable is *a clean, classified inbox*. The discipline this phase enforces: no signal is lost between Gmail, Calendar, Notion, and your head — it lands in version-controlled markdown with provenance, and a human (or `/dd:raw:process`) decides what to do with it.

Sources, filters, and the `raw/` root path are project-specific and live in `<repo>/.drydock/config.yaml`. The commands themselves are universal.

### 2. Requirements (`/dd:req:*`)

Distill captured signals into intent before writing code.

- **Vision & Scope** — why the project exists, what is in scope, what is out.
- **Stakeholder profiles** — who has what interests.
- **Use cases** — how specific actors achieve specific goals (Wiegers/Cockburn form).
- **ADRs** — architectural decisions with context, options, and consequences.
- **Elicitation plan** — what to gather, from whom, by which technique.
- **Requirements review** — quality gate against Wiegers criteria.

The deliverable is *alignment*, not pages. Short documents that actually get read beat exhaustive ones that don't.

### 3. Plan (`/dd:plan:*`)

Move requirements into a tracker so work has shape, owner, and order.

- **add** — capture a new backlog item as a GitHub issue with the right labels and template.
- **triage** — assign Priority, Phase, Area, parent epic.
- **promote** — turn a triaged issue into an OpenSpec change in the right repo (Area → repo routing comes from config).

The deliverable is *a backlog where every item is ready to be picked up*. No nameless tickets, no orphan items, no "what was I supposed to do here?".

### 4. Build (`/dd:build:*`)

Each change to system behavior goes through an OpenSpec change.

- **start** — create a branch (and optional worktree) plus an OpenSpec change skeleton.
- **explore** — Q&A mode for ambiguous scope; output feeds the design.
- **design** — proposal + design + tasks (the three OpenSpec artifacts).
- **ff** — fast-forward: generate all artifacts in one pass for well-understood work.
- **code** — work through the tasks list, checking items as they complete.
- **test** — run the repo's test suite per its conventions.
- **verify** — pre-archive check that tasks are complete, deltas consistent, references resolved.

The deliverable is *working code with a matching change artifact*. The change is a forcing function: it makes the AI (and the human) think before typing.

### 5. Ship (`/dd:ship:*`)

Every change reaches the main branch through the same pipeline.

- **pr** — open a PR linked to the change and the originating requirement.
- **archive** — after merge, archive the change and sync deltas into `openspec/specs/`.
- **release** — cut a version when appropriate; runs configured gates, generates changelog, tags, propagates pins to dependent repos.

The deliverable is *trust*: a release where every line of code is defensibly where it is.

## Project-specific extensions

The five phases above are universal. Anything project-specific — Apilize Protocol conformance tests, public-ready guards, Gmail filter sets, Notion DB IDs, area-to-repo routing — lives **inside the consuming repo** through three extension points:

| Where | What | Invoked by |
|---|---|---|
| `<repo>/.drydock/config.yaml` | Declarative configuration: paths, sources, filters, gates, routing | All Drydock commands that touch project state |
| `<repo>/.drydock/hooks/` | Shell scripts at lifecycle points (`pre-pr.sh`, `pre-release.sh`, `post-capture.sh`, …) | The corresponding command, by convention |
| `<repo>/.claude/commands/` | Project-local slash commands (`/conformance`, `/parity`, `/<your-thing>`) | Referenced from `config.yaml`, e.g. `release.gates: [/conformance, /parity]` |

This is what makes Drydock *one plugin for all projects* without being domain-specific. The plugin code stays universal; each project carries its own specifics in version control, next to the code those specifics affect. See [extension-model.md](extension-model.md) for the full schema.

## Non-goals

Drydock is not:

- A project manager. It does not track status for you; it integrates with existing trackers (GitHub Projects, Linear).
- A generator. It does not invent features. It supports the human in making thoughtful ones.
- A replacement for engineering judgment. It is scaffolding; what you build on top is still yours.
- A multi-plugin family. There is **one** plugin (`drydock`); project specifics live in the project's own repo, never in a sibling plugin.

## When not to use Drydock

Drydock's overhead is worth it when changes have **non-trivial blast radius** — multiple files, user-facing behavior, or cross-cutting concerns. For one-off scripts, throwaway experiments, or pure research code, skip the workflow entirely; using Drydock there is cosplay, not craft.

## Further reading

- [workflow.md](workflow.md) — the concrete, step-by-step loop.
- [extension-model.md](extension-model.md) — config schema, hook lifecycle, command-reference contract.
- [skills-catalog.md](skills-catalog.md) — what each skill does and when to invoke it.
- [migration-from-apz.md](migration-from-apz.md) — for users coming from the internal APZ plugin (now retired).
- [ADR-0004](../requirements/adr/0004-universal-workflow-and-project-extensions.md) — the decision record behind the pentaphase workflow and extension model.
- Wiegers, K. & Beatty, J., *Software Requirements, 3rd Edition*, Microsoft Press, 2013.
- OpenSpec: [https://github.com/openspec/openspec](https://github.com/openspec/openspec) *(link TBD)*.
