# Methodology

Shipwright turns AI-assisted development into a disciplined, traceable loop. It combines three well-established bodies of work and adds a minimal glue layer on top:

1. **Karl Wiegers' requirements engineering** — vision & scope, stakeholder profiles, use cases, ADRs, requirements review.
2. **OpenSpec** — changes-as-artifacts: each modification of behavior is described before it is implemented, with a tasks list and deltas that fold back into living specs.
3. **Claude Code** — as the execution environment (plugin, skills, agents, MCP).

The core claim of Shipwright is simple: **the bottleneck in AI-assisted software development is not generation speed — it is coherence.** A Claude Code session that produces 500 lines of code in an hour is only valuable if those 500 lines are traceable to a requirement, reviewable against a spec, and safe to ship.

## Three phases

### 1. Requirements (`/sw:req:*`)

Capture intent before writing code.

- **Vision & Scope** — why the project exists, what is in scope, what is out.
- **Stakeholder profiles** — who has what interests.
- **Use cases** — how specific actors achieve specific goals (Wiegers/Cockburn form).
- **ADRs** — architectural decisions with context, options, and consequences.
- **Requirements review** — quality gate against Wiegers criteria.

The deliverable is *alignment*, not pages. Short documents that actually get read beat exhaustive ones that don't.

### 2. Build (`/sw:build:*`)

Each change to system behavior goes through an OpenSpec change:

- **start** — create a branch and OpenSpec change skeleton.
- **explore** — Q&A mode for ambiguous scope; output feeds the design.
- **design** — proposal + design + tasks (the three OpenSpec artifacts).
- **code** — work through the tasks list, checking items as they complete.
- **test** — run the repo's test suite per its conventions.

The deliverable is *working code with a matching change artifact*. The change is a forcing function: it makes the AI (and the human) think before typing.

### 3. Ship (`/sw:ship:*`)

Every change reaches the main branch through the same pipeline:

- **pr** — open a PR linked to the change and the originating requirement.
- **archive** — after merge, archive the change and sync deltas into `openspec/specs/`.
- **release** — cut a version when appropriate; changelog and tags are generated.

The deliverable is *trust*: a release where every line of code is defensibly where it is.

## Non-goals

Shipwright is not:

- A project manager. It does not track status for you; it integrates with existing trackers (GitHub Projects, Linear).
- A generator. It does not invent features. It supports the human in making thoughtful ones.
- A replacement for engineering judgment. It is scaffolding; what you build on top is still yours.

## When not to use Shipwright

Shipwright's overhead is worth it when changes have **non-trivial blast radius** — multiple files, user-facing behavior, or cross-cutting concerns. For one-off scripts, throwaway experiments, or pure research code, skip the workflow entirely; using Shipwright there is cosplay, not craft.

## Further reading

- [workflow.md](workflow.md) — the concrete, step-by-step loop.
- [skills-catalog.md](skills-catalog.md) — what each skill does and when to invoke it.
- Wiegers, K. & Beatty, J., *Software Requirements, 3rd Edition*, Microsoft Press, 2013.
- OpenSpec: [https://github.com/openspec/openspec](https://github.com/openspec/openspec) *(link TBD)*.
