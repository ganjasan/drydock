## ADDED Requirements

### Requirement: /dd:feature command

Drydock SHALL expose a top-level command `/dd:feature` (file: `commands/feature.md`) that orchestrates the chain `idea → raw capture → code exploration → clarifying questions → issue + change → branch + worktree → architecture → design + tasks → implementation → tests → draft PR`. The command MUST delegate every phase to an existing per-phase command or skill rather than reimplementing phase logic. The argument is an optional one-line idea statement; absence prompts the user (or resumes an in-flow state).

#### Scenario: Idea-to-PR end-to-end on a clean workspace
- **WHEN** `/dd:feature "add a /dd:scratch command for ad-hoc notes"` is invoked on a clean Drydock-shaped repo
- **THEN** the command MUST produce, in order: a raw entry under `<paths.raw_root>/<paths.raw_subdirs.ideas>/`, a cached code-exploration file, a GitHub issue, an OpenSpec change directory, a feature branch (and worktree if configured), a `design.md`, a `tasks.md` with at least one task, per-task commits, and a draft PR linked to the issue and the change

#### Scenario: Argument absent prompts for the idea
- **WHEN** `/dd:feature` is invoked with no arguments and no in-flow state is detected
- **THEN** the command MUST prompt the user to enter the idea string before proceeding

#### Scenario: Resume from in-flow state
- **WHEN** `/dd:feature` is invoked and `dd_feature_position` returns a non-`none` phase (e.g., a change exists but no PR)
- **THEN** the command MUST resume at the next pending phase rather than starting over; it MUST print the detected phase before proceeding

### Requirement: Phase pause-and-continue protocol

After each phase, `/dd:feature` SHALL either auto-continue or pause based on `feature.pause_after.<phase>`. When paused, the command MUST present an action prompt with `[c] continue · [s] stop here · [r] redo this phase · [j] jump to phase: __` and default to `c` on Enter. A "stop here" choice MUST exit cleanly with all artifacts already produced retained on disk and a printed resume hint naming the per-phase command that resumes the next step.

#### Scenario: Default pause cadence
- **WHEN** `/dd:feature` is invoked with default config (no `feature.pause_after.*` overrides)
- **THEN** the command MUST pause after phases `idea`, `clarify`, `design`, and `pr` and MUST auto-continue past `explore`, `promote`, `code`, `test`

#### Scenario: Configurable pause override
- **WHEN** `feature.pause_after.code: true` is configured and the implementation phase completes a task
- **THEN** the command MUST pause and present the pause prompt before continuing to the next task

#### Scenario: Stop-here exits cleanly with resume hint
- **WHEN** the user enters `s` at the pause prompt after the architecture phase
- **THEN** the command MUST exit non-zero, print `Resume with: /dd:build:design` (or the appropriate per-phase command for the saved state), and leave the workspace's existing artifacts intact

### Requirement: Recoverable mid-flow exit at every checkpoint

`/dd:feature` MUST guarantee that any mid-flow exit (chosen `s` or interrupted) leaves the workspace in a state where the corresponding per-phase command can resume. Specifically: a raw idea entry survives as a normal raw entry; the cached code-exploration file survives at its current path (`<workdir>/.feature-exploration.md` before a change exists, `<change>/.exploration.md` after); a created issue and change survive as normal; a created branch and worktree survive; an architect draft is preserved as `<change>/design.draft.md` if not yet applied to `design.md`.

#### Scenario: Architect draft preserved on stop-here
- **WHEN** the architect produces a draft `design.md` body and the user chooses `s` at the design pause before accepting
- **THEN** the draft MUST be saved at `<change>/design.draft.md` and `/dd:build:design` invoked subsequently MUST detect the draft and offer to use it

#### Scenario: Exploration cache survives a mid-flow exit
- **WHEN** the user chooses `s` at the explore pause
- **THEN** `<workdir>/.feature-exploration.md` MUST exist with the explorer's output and a `cached_at` frontmatter field; a subsequent `/dd:feature` invocation MUST detect and reuse it without re-invoking `dd:code-explorer`

#### Scenario: No orphan state files
- **WHEN** the user stops at any phase
- **THEN** the workspace MUST NOT contain a `.feature-state.*`, `.flow-state.*`, or similar orchestrator-private state file; all phase-state MUST be derivable from artifacts (`raw/`, GitHub issues, `openspec/changes/`, branches, PR). The exploration cache and clarifying-answers scratch files are pre-artifact intermediate outputs, not phase-state — their presence does not influence `dd_feature_position`

### Requirement: Single exploration pass; architect reuses the output

`/dd:feature` SHALL invoke `dd:code-explorer` exactly once per run, on phase 2 (before clarifying questions). The explorer's output MUST be cached at `<workdir>/.feature-exploration.md` (before a change exists) or `<change>/.exploration.md` (after change creation). On phase 6, when the orchestrator dispatches `dd:code-architect`, the architect's prompt MUST include the cached exploration as ground truth and MUST explicitly instruct the architect not to re-traverse the codebase. The user MAY force re-exploration via `[r] redo this phase` at the explore-phase pause, which MUST delete the cache and re-invoke the explorer.

#### Scenario: Single exploration per flow
- **WHEN** `/dd:feature` runs end-to-end on a clean workspace
- **THEN** `dd:code-explorer` MUST be dispatched exactly once across the full run

#### Scenario: Architect prompt includes cached exploration
- **WHEN** the orchestrator enters phase 6 and dispatches `dd:code-architect`
- **THEN** the agent invocation prompt MUST include the contents of the cached exploration file and MUST contain a "do not re-traverse the codebase" instruction

#### Scenario: Redo at explore pause re-invokes explorer
- **WHEN** the user selects `[r] redo this phase` at the explore pause
- **THEN** the cache file MUST be deleted and `dd:code-explorer` MUST be invoked again before continuing

#### Scenario: Cache survives change creation move
- **WHEN** phase 2 produces `<workdir>/.feature-exploration.md` and phase 4 creates `openspec/changes/<slug>/`
- **THEN** the cache MUST be moved to `<change>/.exploration.md` so it travels with the change for downstream phases

### Requirement: Idea-capture phase with raw integration

The idea-capture phase SHALL invoke the `raw-capture` skill with synthetic frontmatter `source: manual`, `proposed_category: ideas`, `captured_by: claude-code:/dd:feature`, and a `dedup_key` derived from `manual:<sha-of-idea-body>`. When `feature.idea_destination: skip` is configured, this phase MUST be skipped entirely and the orchestrator MUST proceed directly to issue creation, prompting for the issue title from the idea string.

#### Scenario: Default idea capture lands in ideas subdir
- **WHEN** `/dd:feature "<idea>"` is invoked with default config
- **THEN** a new file MUST be written to `<paths.raw_root>/<paths.raw_subdirs.ideas>/` (or `<paths.raw_root>/_incoming/` and then classified — implementation choice) with frontmatter `source: manual`, `proposed_category: ideas`, `captured_by: claude-code:/dd:feature`

#### Scenario: Skip idea destination
- **WHEN** `feature.idea_destination: skip` is configured and `/dd:feature "<idea>"` is invoked
- **THEN** the command MUST NOT write any raw entry; the next observable action MUST be issue creation via `/dd:plan:add`

### Requirement: Structured clarifying-questions output captured into proposal.md

The `feature-clarify` skill SHALL produce as many clarifying questions as the spec depends on (zero if the codebase + idea are unambiguous; no upper cap). Each question MUST have one recommended answer, 2–4 named alternatives, a `[d] discuss this further` option that opens `openspec-explore` for that thread, and a `[?] defer to design.md § Open Questions` option. Selected answers MUST be appended to `<change>/proposal.md` under a `### Clarifying answers` subsection within the existing `## Context` heading. Questions for which the user chose `[?]` MUST be appended to `<change>/design.md` under `## Open Questions`. Questions MUST be generated one at a time conditioned on prior answers, and the skill MUST terminate when no critical ambiguity remains.

#### Scenario: Zero questions when no ambiguity
- **WHEN** `/dd:feature "rename function foo to bar"` is invoked on a fixture repo where `foo` is defined exactly once and the rename is mechanically obvious
- **THEN** `feature-clarify` MUST produce zero questions and the flow MUST proceed directly past the clarify phase

#### Scenario: Each question has a recommendation, alternatives, discuss, and defer
- **WHEN** any clarifying question is presented
- **THEN** the question's option list MUST include exactly one recommended option (marked `← recommended`), 2–4 alternatives, exactly one `[d] discuss this further` option, and exactly one `[?] defer` option

#### Scenario: Discuss escape opens openspec-explore
- **WHEN** the user answers `d` to a clarifying question
- **THEN** the orchestrator MUST invoke `openspec-explore` with the question text as the prompt; on return, MUST present the next clarifying question

#### Scenario: Defer reservation appends to design.md Open Questions
- **WHEN** the user answers `?` to a clarifying question
- **THEN** the orchestrator MUST append that question to `<change>/design.md` § Open Questions and MUST continue the flow without blocking

#### Scenario: Captured answers in proposal.md
- **WHEN** the clarifying phase completes with at least one answered question
- **THEN** `<change>/proposal.md` MUST contain a `### Clarifying answers` subsection under `## Context` with one bullet per answered question

#### Scenario: Questions grounded in cached exploration
- **WHEN** the cached exploration identifies a specific module (e.g., `lib/auth/session.ts`) and a clarifying question is generated about that area
- **THEN** the question text MUST reference the actual file path or pattern from the exploration, not abstract terms

### Requirement: Flow-state detection without state file

`/dd:feature` SHALL determine current flow position by inspecting workspace artifacts (raw entries, GitHub issues, OpenSpec changes, branches, `tasks.md` checkboxes, open PRs) via `lib/feature_state.sh::dd_feature_position`. The orchestrator MUST NOT write a flow-specific phase-state file. The exploration cache and clarifying-answers scratch files are pre-artifact intermediate outputs and MUST NOT be considered phase-state by the position detector.

#### Scenario: Resume detection
- **WHEN** a feature branch with a linked OpenSpec change exists, `tasks.md` has unchecked items, and `/dd:feature` is invoked with no arguments
- **THEN** `dd_feature_position` MUST return `designed` (or the appropriate post-design pre-implementation phase) and the orchestrator MUST resume at the implementation phase

#### Scenario: No phase-state file written
- **WHEN** `/dd:feature` runs to any checkpoint and exits
- **THEN** the workspace MUST NOT contain any new file named `.feature-state*`, `.flow-state*`, `feature-state.*`, or any similar orchestrator-private phase-state file

### Requirement: feature.* configuration schema

Drydock SHALL document a `feature.*` configuration schema under `docs/extension-model.md` § feature and provide commented examples in `templates/extension/config.yaml`. The schema MUST cover at minimum: `feature.pause_after.{idea,explore,clarify,promote,design,code,test,pr}` (booleans, defaults per design D3) and `feature.idea_destination` (`raw|skip`, default `raw`).

#### Scenario: Schema documentation present
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST contain a `feature.*` section listing every key above with type, default, and one-sentence purpose

#### Scenario: Template ships feature block commented
- **WHEN** a user inspects `templates/extension/config.yaml`
- **THEN** the file MUST contain a fully commented `feature.*` block with universal example values

### Requirement: Universal — no organization-specific defaults

The `commands/feature.md` file, the `feature-orchestrate` and `feature-clarify` skill bodies, and the `lib/feature_state.sh` helper MUST NOT contain hardcoded references to specific organizations, clients, or product names.

#### Scenario: Universality grep
- **WHEN** an inspector greps `commands/feature.md`, `skills/feature-orchestrate/`, `skills/feature-clarify/`, and `lib/feature_state.sh` for any client or product name (e.g., known past values like "apilize", "wertxpert", "intreal")
- **THEN** zero matches MUST be found
