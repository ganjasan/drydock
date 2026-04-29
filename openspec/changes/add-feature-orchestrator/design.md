## Context

Drydock's pentaphase workflow is enforced through one slash command per phase boundary. That fragmentation is intentional — every command is a checkpoint where the user can audit, redirect, or refuse — but it puts the orchestration burden on the user. Users who already know the next eight commands they're going to type want one command that types them in order.

The `feature-dev` plugin (also installed in this user's environment) ships a single conversational flow from idea to design. The user explicitly asked for a Drydock-flavored equivalent, with three named departures from `feature-dev`'s shape:

1. The flow must **start by recording the idea** as a raw entry, so the original framing survives even if the implementation diverges later.
2. The clarifying-questions step must be **structured** (multi-choice with recommendations) rather than free-form Q&A, so the user can answer with single keystrokes and the captured answers can be programmatically inserted into the change's `proposal.md`.
3. The code-exploration step must run **before clarifying questions**, so questions are grounded in the actual codebase rather than asked in a vacuum. The exploration result is then reused by the architect on the design step instead of running a second exploration pass.

The constraint set:

- **Phase gates remain inviolable.** The orchestrator is a sequencer, not a shortcut. Every phase ends with the same artifact and the same workspace state as if the user had run the per-phase command manually.
- **Stepping out is always safe.** A user who hits Ctrl-C or chooses "stop here" must find a workspace where every per-phase command can resume from the last completed checkpoint.
- **No duplication.** The orchestrator MUST NOT re-implement the body of `/dd:plan:add`, `/dd:plan:promote`, `/dd:build:start`, etc. It calls them. If a per-phase command's behavior changes, `/dd:feature` inherits the change for free.
- **Universal.** As with all Drydock commands, no organization-specific values appear in the command file or the skill bodies.

## Goals / Non-Goals

**Goals:**

- A single command, `/dd:feature`, that takes an idea string and walks the user from raw capture to draft PR, pausing at configurable checkpoints.
- A structured clarifying-questions skill (`feature-clarify`) whose output drops directly into a change's `proposal.md` § Context.
- A single code-exploration pass (phase 2) whose output is reused everywhere downstream, including as the architect's grounding context on phase 6.
- Per-phase configurability via `feature.pause_after.*` so a user can tune the cadence without forking the command.
- Recoverable mid-flow exit at every checkpoint.

**Non-Goals:**

- Replacing the per-phase commands. They remain the canonical entry points and `/dd:feature` documents itself as a convenience.
- Multi-issue or multi-change orchestration. One flow handles one idea → one issue → one change → one PR. Splitting into multiple changes is a manual decision after the design step.
- Auto-merging, auto-archiving, or auto-releasing. The flow ends at "draft PR opened"; everything after that is human review and the existing `/dd:ship:*` commands.
- Replacing `/dd:build:explore` or `openspec-explore`. The free-form thinking partner stays; `feature-clarify` is a structured complement, not a replacement.
- Capping the number of clarifying questions. The skill emits as many as the spec actually depends on — zero if the codebase + idea are unambiguous, more if not.

## Decisions

### D1. Single top-level command, not a `/dd:feature:*` namespace

`/dd:feature` is one command, at `commands/feature.md`, alongside `commands/status.md` and `commands/next.md`. Splitting into `/dd:feature:start`, `/dd:feature:continue`, etc. would re-fragment what we're trying to consolidate.

Resume semantics live inside the single command: when invoked with no arguments and an in-progress feature flow detected (active OpenSpec change without a PR), the command picks up at the next pending phase. This matches how `/opsx:continue` already works.

Alternative considered: `/dd:feature:start` + `/dd:feature:continue` + `/dd:feature:status`. Rejected — three commands to do what one command can do with branchy logic on entry.

### D2. The orchestrator is a thin shell over existing commands

`/dd:feature` does not implement raw filing, issue creation, branch management, or PR creation. It calls the existing commands:

| Phase | Delegates to |
|-------|--------------|
| 1. Capture idea | `skills/raw-capture` (with a synthetic `proposed_category: ideas`) |
| 2. Explore code | spawns `dd:code-explorer` Agent — single pass, output cached for downstream phases |
| 3. Clarify | `skills/feature-clarify` (new) — receives the explorer's output as grounding context |
| 4. Issue + change | `/dd:plan:add` then `/dd:plan:promote` |
| 5. Branch + worktree | `/dd:build:start` |
| 6. Architecture | spawns `dd:code-architect` Agent — receives the cached explorer output as ground truth, does not re-explore |
| 7. Design + tasks | `/dd:build:design` (or `/dd:build:ff` for well-scoped work) |
| 8. Implement | loop over `/dd:build:code` until `tasks.md` is fully checked |
| 9. Test | `/dd:build:test` |
| 10. PR | `/dd:ship:pr` |

The flow command's body is mostly state inspection (where are we?) plus dispatch.

Rationale: any time a per-phase command improves, the flow inherits it. No drift between the umbrella and the underlying steps.

Alternative considered: inline the body of each command into `feature.md`. Rejected — drift inevitable, a flow that diverges from the canonical commands defeats its own purpose.

### D3. Pause-after-phase semantics, configurable per checkpoint

After each phase, the orchestrator prints a short summary of what just happened (one line per artifact created or modified) and then either:

- **Auto-continues** if `feature.pause_after.<phase>: false`, with a single-line "→ continuing to <next phase>" log entry; OR
- **Pauses** if `feature.pause_after.<phase>: true`, prompting:

  ```
  Phase <N> done — <one-line summary>.
  [c] continue · [s] stop here · [r] redo this phase · [j] jump to phase: __

  Default: c (Enter to continue)
  ```

Defaults make sense for the median user:
- `pause_after.idea: true` — the user just typed the idea; confirm before code exploration kicks off.
- `pause_after.explore: false` — exploration is read-only, no need to pause.
- `pause_after.clarify: true` — clarifying answers materially shape the proposal.
- `pause_after.promote: false` — issue creation is mechanical.
- `pause_after.design: true` — the architecture proposal is the single biggest artifact; user must approve before writing code.
- `pause_after.code: false` — implement-then-test runs cleanly when tasks are well-scoped.
- `pause_after.test: false` — same.
- `pause_after.pr: true` — final review of the PR body before opening (default to draft anyway).

Stop-here exits cleanly: artifacts already produced are kept; the flow command prints exactly which per-phase command picks up the next step.

### D4. The clarifying-questions skill produces a closed-form answer-space, with as many questions as needed

`feature-clarify` does not ask freeform questions like "what about X?". Each question must have:

- a **single recommended answer** (the agent's best guess, usable when the user just hits Enter),
- 2–4 **named alternatives** (each with a one-line reasoning hint),
- exactly one **"discuss this"** option that escapes into `openspec-explore` for that thread,
- exactly one **"defer"** option that records the question as an Open Question in `design.md` without blocking the flow.

Format:

```
Q1. <question>
    [a] <recommended option>          ← recommended
    [b] <alternative>
    [c] <alternative>
    [d] discuss this further (opens openspec-explore)
    [?] defer to design.md § Open Questions

Default: a
```

A user can answer "a a c a a" in one line for five questions (or just Enter for "all defaults"), or type "d" on any question to derail into discussion. Discussion mode runs the existing `openspec-explore` for that thread, then returns to the next clarifying question.

The agent emits as many questions as the spec actually depends on. If the codebase plus the idea statement leave no ambiguity, it emits zero questions and the flow proceeds. If the spec depends on twenty unresolved decisions, it emits twenty. There is no upper cap. The agent generates questions one at a time, conditioned on prior answers, so the question set narrows naturally as ambiguity resolves.

The agent reports "no further clarification needed" when:
- every remaining ambiguity it can identify has been answered or deferred, AND
- the next question it would generate is judged "low criticality" (would not change the design, only the implementation details).

Captured answers are appended to the change's `proposal.md` under `## Context` as:

```markdown
### Clarifying answers
- **<question>** → <answer chosen>
- **<question>** → <answer chosen>
```

Rationale: closed-form keeps the cognitive cost of clarification low — a tap-tap-Enter sequence completes a clarification round. The "discuss" escape preserves the openspec-explore depth for cases that actually need it. Removing the cap means users with complex specs are not forced to drop questions onto an Open Questions list that nobody will revisit.

Alternative considered: cap at N (originally proposed N=5). Rejected — when N matters more than it should, the user routinely loses critical questions to the cap; deferring is already a per-question option, so the user always controls breadth.

Alternative considered: use openspec-explore directly. Rejected — that's free-form by design and produces freeform output, which the orchestrator can't drop into `proposal.md` programmatically. The two coexist.

### D5. Single exploration pass on phase 2; architect reuses the output

`/dd:feature` invokes `dd:code-explorer` exactly once per run, on phase 2, before clarifying questions. The explorer's output is:

1. Used as grounding context for `feature-clarify` on phase 3 — questions reference real files and existing patterns rather than abstract scenarios.
2. Cached (in-memory in the orchestrator's running session, or as `<change>/.exploration.md` if the flow pauses across sessions) for reuse on phase 6 — when the orchestrator dispatches `dd:code-architect`, the architect's prompt includes the explorer's full code map as ground truth and is instructed not to re-traverse the codebase.

The architect produces only the `design.md` body (Context / Goals / Decisions / Risks / Migration / Open Questions); it does not duplicate the code-map output. If the user requests a fresh exploration on phase 6 (e.g., the codebase changed mid-flow), `redo this phase` at the explore-phase pause re-invokes the explorer.

Rationale: clarifying questions need to be grounded in the codebase (the user explicitly noted this — "from this the spec can depend"). Running the explorer twice (once for clarify-grounding, once for architecture) wastes cycles when the codebase hasn't changed. One pass, reused, is both faster and more consistent.

Alternative considered: parallel dispatch of explorer and architect on phase 6 (no exploration on phase 2). Rejected — clarifying questions on phase 3 would not be grounded in the codebase, defeating the user's stated requirement that exploration must precede clarification.

Alternative considered: explorer runs every time the orchestrator needs codebase context (phase 2 and phase 6, sequentially each time). Rejected — for a single feature, the codebase is essentially static between those phases, so a second exploration is redundant.

### D6. Idea capture lands as a raw entry by default, skippable for "in-head" ideas

The first phase calls `skills/raw-capture` with a synthetic frontmatter:

```yaml
source: manual
captured_at: <now>
dedup_key: manual:<sha-of-idea>
proposed_category: ideas
captured_by: claude-code:/dd:feature
```

The body is the user's idea text. The post-capture lifecycle hook fires per the existing protocol.

For users who don't want a raw entry per flow invocation (e.g., implementing from a backlog item already filed manually), `feature.idea_destination: skip` skips this phase entirely and the orchestrator starts at the issue-creation step, prompting for the issue title from the idea string.

Rationale: dogfooding ADR-0002 says the idea-capture step is the left edge of every Drydock-shaped feature. Default-on captures every idea; opt-out covers the case where the idea is already filed.

Alternative considered: never auto-capture. Rejected — users will routinely lose the original framing of an idea after the design pass rewrites the proposal in technical terms.

### D7. Recoverable exit at every checkpoint

Every phase boundary leaves the workspace in a state where the per-phase command can resume:

| After phase | Resumable via |
|-------------|---------------|
| 1. Capture idea | `/dd:plan:add` (idea is a filed raw entry; user can promote to issue manually) |
| 2. Explore | `/dd:plan:add` (exploration cached at `<workdir>/.feature-exploration.md` if user stops; rerun `/dd:feature` to reuse it without re-exploring) |
| 3. Clarify | `/dd:plan:add` (clarifying answers stored in a scratch file `<workdir>/.feature-clarifying-answers.md` if no change exists yet; if one exists, in `proposal.md`) |
| 4. Issue + change | `/dd:build:start` (issue + change exist; user starts manually) |
| 5. Branch + worktree | `/dd:build:design` |
| 6. Architecture | `/dd:build:design` (design draft is saved as `<change>/design.draft.md` if user stops mid-design; existing command picks it up) |
| 7. Design + tasks | `/dd:build:code` |
| 8. Implement | `/dd:build:code` (per-task commit; resume mid-loop is normal) |
| 9. Test | `/dd:ship:pr` |
| 10. PR | (terminal — no further auto-step) |

The orchestrator prints the resume hint on every exit. Example:

```
Stopped at phase 5 (Architecture).
Saved: openspec/changes/<slug>/design.draft.md (architect output, not yet applied)
Resume with: /dd:build:design  (or rerun /dd:feature to continue from here)
```

### D8. Flow-state detection: presence of artifacts, not a state file

`/dd:feature` does not write its own state file. It detects current position by inspecting:

- raw inbox: is there an unprocessed idea entry from this flow? (matched by `dedup_key`)
- GitHub issues: is there an open issue with `traces_to` pointing to that idea?
- OpenSpec change: is there a change linking to that issue?
- Branch / worktree: is there a `feature/<N>-*` branch?
- `tasks.md`: are there unchecked tasks? (count)
- PR: is there an open PR linking the change?

The detection logic is shared with `/dd:status` and `/dd:next` (both already do similar inspection); `lib/feature_state.sh` is the new helper that exposes a `dd_feature_position` function returning the current phase index.

The exploration cache file (`<workdir>/.feature-exploration.md`) and the clarifying-answers scratch file (`<workdir>/.feature-clarifying-answers.md`) are not state — they're pre-artifact intermediate outputs that have an obvious purpose, are gitignored, and would be regenerated by re-running their phase. Their presence does not change the phase that `dd_feature_position` reports; that comes purely from the artifact graph.

Rationale: a state file would drift from reality. The artifacts ARE the state.

Alternative considered: write `<change>/.feature-state.yaml` with the current phase. Rejected — duplicates state already discoverable from artifacts; introduces a new failure mode (stale state file).

### D9. Universal categories for clarifying questions

`feature-clarify` operates against five canonical question categories:

1. **Scope** — what's in vs. out of this feature.
2. **User experience** — observable behavior the user sees.
3. **Data model** — what's stored, where, and what shape.
4. **Integration** — what existing systems this touches.
5. **Constraints** — perf, compliance, deadlines, prior commitments.

The agent picks questions across these categories, weighted by criticality (a scope question that affects MVP vs. v2 outranks an integration question about a logging library version). Categories are a guide for the agent's question generation, not a quota — a feature whose scope is crystal-clear may produce zero scope questions and several integration ones.

These categories are documented in the skill body, not configurable. Rationale: the categories are a methodology choice (what every feature needs clarified before design starts), not a project-specific preference. Adjusting them belongs in a Drydock release, not a config knob.

## Risks / Trade-offs

- [Risk] **Users grow to depend on `/dd:feature` and stop running per-phase commands directly, losing the discipline-by-friction the per-phase commands provide.** → **Mitigation**: every pause point names the per-phase command that does the same step manually; the resume hint always cites the per-phase entry point. Documentation positions `/dd:feature` as "the chain", with per-phase commands as the canonical units.
- [Risk] **Cached exploration goes stale if the codebase changes mid-flow.** → **Mitigation**: exploration cache file includes a `cached_at` timestamp; the architect prompt instructs it to flag any cited file that no longer exists at the same path. The user can force re-exploration by selecting `[r] redo this phase` at the explore-phase pause.
- [Risk] **`feature-clarify` recommends bad defaults; user just hits Enter and ships a wrong design.** → **Mitigation**: the recommended answer is always one of the alternatives, never a unique sui-generis option, so the user is selecting from a visible space; "discuss" escape is one keystroke away; the design pause requires explicit confirmation before code starts.
- [Risk] **Without a question cap, the agent could ask 50 questions and exhaust the user's patience.** → **Mitigation**: the agent's "no further clarification needed" criterion (criticality threshold) prevents infinite questioning; the user can always type `?` to defer remaining questions to design.md Open Questions; the user can also choose `[s] stop here` at the clarify pause to skip remaining questions entirely.
- [Trade-off] **The orchestrator increases coupling between phase commands.** Accepted: the coupling already exists informally (the workflow assumes ordering); making it explicit lets us test the chain end-to-end.
- [Trade-off] **Idea-capture default is on, even for trivial flows.** Accepted: aligns with ADR-0004 (raw is the universal left edge). Users who routinely flow trivial work can flip `feature.idea_destination: skip`.

## Migration Plan

This is purely additive. No existing command, agent, or skill is removed. No frontmatter or config schema changes are breaking — the `feature.*` namespace is new.

Rollout:

1. Ship `/dd:feature`, `feature-clarify`, `feature-orchestrate` together with their tests.
2. Update `docs/workflow.md` with the "End-to-end shortcut" subsection that contrasts the umbrella with the per-phase chain.
3. After one release cycle, gather usage feedback (e.g., do users actually pause at design, or do they just hit Enter through everything? How many clarifying questions per flow on average?). Adjust defaults in v0.x.

Rollback: delete `commands/feature.md`, `skills/feature-clarify/`, `skills/feature-orchestrate/`, `lib/feature_state.sh`. Per-phase commands continue to work because they were never modified.

## Open Questions

- **Should the flow auto-run `/dd:build:test` after each `/dd:build:code` task, or only after all tasks complete?** — Decision: only after all tasks complete (Phase 9). Per-task tests are the responsibility of `/dd:build:code` itself; the orchestrator's test phase is the full-suite regression. If the flow detected per-task test failures it would have aborted earlier in `/dd:build:code`.
- **Should `/dd:feature` be invokable from inside an active worktree, or only from main?** — Decision: invokable from anywhere. If a worktree is detected, the orchestrator detects the existing flow state via D8 and resumes; if the existing flow state is incompatible (different change), it refuses with a clear message and points the user to `/dd:status`.
- **How does the orchestrator behave when the user's first answer to a clarifying question makes a later question moot?** — Decision: the agent does NOT precompute all questions before the first answer. It generates one question at a time, conditioned on prior answers, until either it runs out of critical ambiguities or the user defers all remaining ones. This is more conversational at the cost of slightly higher per-turn latency.
- **Should there be a `--dry-run` flag that walks the phases without writing anything?** — Decision: not in v1. Useful for testing the orchestrator itself, but a v0.x test harness can fake the per-phase commands instead of adding a flag to user-facing flow.
- **Where exactly does the cached exploration live across sessions — `<workdir>/.feature-exploration.md` or `<change>/.exploration.md`?** — Decision: `<workdir>/.feature-exploration.md` before a change exists (phase 2 happens before phase 4); after the change exists (phase 4+), the file moves into `<change>/.exploration.md` so it travels with the change. Both paths are gitignored.
