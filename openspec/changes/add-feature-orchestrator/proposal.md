## Why

Drydock teaches a five-phase workflow (`raw → req → plan → build → ship`) and ships one command per checkpoint. That discipline is the point — every phase is a place where a human can stop, reroute, or refuse — but it costs throughput when a user already knows what they want and just wants the obvious chain to run end-to-end. Today that chain is at least eight separate slash commands (`/dd:raw:capture` → `/dd:plan:add` → `/dd:plan:promote` → `/dd:build:start` → `/dd:build:explore` → `/dd:build:design` → `/dd:build:code` → `/dd:build:test` → `/dd:ship:pr`), each with its own preflight, and the user has to remember the order.

The other plugin in this user's daily kit (`feature-dev`) collapses idea → exploration → architecture into a single conversational flow. Users want a Drydock-shaped equivalent: one entry point that takes an idea, walks the discipline, but does the connective work automatically — including code exploration before clarifying questions (so questions are grounded in what's actually in the codebase) and a structured clarifying-questions step that today exists only as the free-form `openspec-explore` skill.

The constraint: the orchestrator must NOT bypass the phase gates that make Drydock's methodology work. It must surface every checkpoint as a confirmation, default to "continue", and let the user step out of the flow at any point with the intermediate state intact (raw entry filed, issue open, change scaffolded, branch created, etc.). Stepping out must leave the workspace in a state the existing single-purpose commands can pick up.

## What Changes

- **NEW** `/dd:feature` — top-level command at `commands/feature.md`. Orchestrates the full idea-to-PR chain with explicit pause points after every phase. Argument: an optional one-line idea statement (or empty for prompt).
- **NEW** `skills/feature-clarify/SKILL.md` — structured clarifying-questions skill. Distinct from `openspec-explore` (free-form thinking partner): produces a numbered list of questions where each has a recommended answer, 2–4 alternatives, and an "open thread" option to expand into discussion. The skill emits as many questions as needed — zero if the codebase + idea are unambiguous, dozens if the spec depends on it. Output is captured into the change's `proposal.md` Context section.
- **NEW** `skills/feature-orchestrate/SKILL.md` — the orchestration body invoked by `commands/feature.md`. Encapsulates the phase walk so a future caller (e.g., a `/dd:resume-feature` command, or a test fixture) can replay the same sequence.
- **MODIFIED** `agents/code-explorer.md` is unchanged in behavior, but `/dd:feature` invokes it once on phase 2 (before clarifying questions) and reuses the output through the rest of the flow — including as the architect's grounding context on phase 6, so the architect never re-explores.
- **MODIFIED** `commands/README.md` adds a "Top-level" entry for `/dd:feature` with a one-liner.
- **MODIFIED** `docs/workflow.md` adds an "End-to-end shortcut" subsection documenting `/dd:feature` as the umbrella over the per-phase commands, with an explicit note that the per-phase commands remain the canonical path and `/dd:feature` is a convenience.
- **NEW** `feature.*` configuration schema:
  - `feature.pause_after.{idea,explore,clarify,promote,design,code,test,pr}` — boolean, default `true` for `idea`, `clarify`, `design`, `pr`; default `false` for the rest. Lets users tune which checkpoints require a confirmation tap and which auto-continue.
  - `feature.idea_destination` — `raw` (default; files into `<paths.raw_root>/<paths.raw_subdirs.ideas>/`) or `skip` (no raw entry, jump straight to issue creation).

## Capabilities

### New Capabilities

- `feature-orchestration`: the `/dd:feature` command, the `feature-orchestrate` skill, the phase-by-phase pause-and-continue protocol, the structured clarifying-questions format, the single-pass code exploration (run once on phase 2, reused on phase 6 for architecture), the per-phase exit semantics (each pause leaves a recoverable workspace), and the `feature.*` configuration schema.

### Modified Capabilities

- `command-suite`: add `/dd:feature` to the top-level command set documented in `commands/README.md`.
- `skill-library`: add `feature-clarify` and `feature-orchestrate` to the shipped skill set.

## Impact

- **Code:** new `commands/feature.md`; new `skills/feature-clarify/SKILL.md`; new `skills/feature-orchestrate/SKILL.md`. No changes to existing command/agent/skill files beyond the `commands/README.md` index update.
- **Docs:** `docs/workflow.md` gains an "End-to-end shortcut" subsection; `docs/skills-catalog.md` lists the two new skills under a new "Feature skills" group.
- **Templates:** `templates/extension/config.yaml` extended with a commented `feature.*` block.
- **Specs:** new `feature-orchestration` spec; deltas against `command-suite` and `skill-library`.
- **Tests:** verify the orchestrator pauses after every phase whose `feature.pause_after.<phase>` is `true`; verify intermediate state (raw entry, issue, change, branch) survives a mid-flow exit; verify `feature-clarify` output structure (each question has a recommendation + 2–4 alternatives + discuss option, no upper bound on count); verify `dd:code-explorer` is invoked exactly once per `/dd:feature` run and its output is reused by `dd:code-architect` on the design step.
- **Methodology integrity:** `/dd:feature` MUST invoke the existing single-purpose commands/skills under the hood, not duplicate their logic. This keeps the orchestrator thin and ensures changes to a phase command propagate into the flow automatically.
- **Breaking-change scope:** none. Purely additive.
