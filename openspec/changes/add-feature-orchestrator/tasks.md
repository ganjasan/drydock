## 1. Command file

- [x] 1.1 Create `commands/feature.md` with frontmatter (`description`, `argument-hint`, `allowed-tools: Bash, Read, Write, Edit, Glob, Grep, SlashCommand, Agent`) and a body that delegates to the `feature-orchestrate` skill
- [x] 1.2 Document the flow's argument: optional one-line idea string; empty triggers a prompt to enter it (or a resume if in-flow state is detected)
- [x] 1.3 Add a Guardrails section listing what the command MUST NOT do (no inline phase logic, no skipping pause points except per `feature.pause_after.*`, no auto-merge / auto-archive / auto-release)

## 2. Orchestrator skill

- [x] 2.1 Create `skills/feature-orchestrate/SKILL.md` with frontmatter and a body that walks the phases per design D2
- [x] 2.2 Implement phase dispatch: each phase calls the corresponding existing command/skill (`/dd:plan:add`, `/dd:plan:promote`, `/dd:build:start`, `/dd:build:design`, `/dd:build:code`, `/dd:build:test`, `/dd:ship:pr`); raw capture calls the `raw-capture` skill directly
- [x] 2.3 Implement pause-after semantics per design D3: print summary, prompt with `[c/s/r/j]`, default `c` (continue) on Enter
- [x] 2.4 Implement single exploration pass (D5): run `dd:code-explorer` exactly once per flow on phase 2; cache output at `<workdir>/.feature-exploration.md` before a change exists, then move to `<change>/.exploration.md` once the change is created on phase 4
- [x] 2.5 Implement architect dispatch on phase 6: invoke `dd:code-architect` with the cached exploration as ground truth; the architect prompt explicitly forbids re-traversing the codebase
- [x] 2.6 Implement recoverable exit per design D7: every "stop here" prints the resume hint pointing to the relevant per-phase command
- [x] 2.7 Implement flow-state detection via `lib/feature_state.sh::dd_feature_position` (artifact-based, no state file)

## 3. Clarifying-questions skill

- [x] 3.1 Create `skills/feature-clarify/SKILL.md` with frontmatter and a body that follows the closed-form question structure per design D4
- [x] 3.2 Define the five canonical question categories per design D9 (Scope, UX, Data model, Integration, Constraints) in the skill body — as a guide for question generation, not a quota
- [x] 3.3 Implement the answer-shorthand parser: a single line of letters (e.g., `a a c a a`) maps to per-question answers; `?` defers the question to Open Questions; `d` opens `openspec-explore` for that thread
- [x] 3.4 Append captured answers to `<change>/proposal.md` § Context as `### Clarifying answers` per design D4
- [x] 3.5 Generate questions one at a time, conditioned on prior answers; terminate when no critical ambiguity remains (per design D4 termination criterion)
- [x] 3.6 Receive cached `dd:code-explorer` output as grounding context so questions reference real files and existing patterns rather than abstract scenarios

## 4. Configuration schema

- [x] 4.1 Extend `lib/config.sh` validation to recognize the `feature.*` namespace
- [x] 4.2 Document `feature.*` schema in `docs/extension-model.md` § feature with per-key types, defaults, and example values
- [x] 4.3 Extend `templates/extension/config.yaml` with a fully commented `feature.*` block (universal example values)

## 5. Flow-state helper

- [x] 5.1 Create `lib/feature_state.sh` with a `dd_feature_position` function that returns one of: `none|idea|explored|clarified|promoted|started|architected|designed|coded|tested|pr` based on artifact inspection
- [x] 5.2 Document the detection logic in the helper file's header comment (which artifact maps to which phase)
- [x] 5.3 Reuse the helper in `commands/status.md` and `commands/next.md` so the new "in-flow" state surfaces in both (replacing or augmenting their existing detection logic)

## 6. Exploration reuse

- [x] 6.1 Implement the exploration cache file write (phase 2): `<workdir>/.feature-exploration.md` with frontmatter `cached_at`, body = explorer's full output verbatim
- [x] 6.2 Implement the cache move on phase 4 (after change creation): mv `<workdir>/.feature-exploration.md` → `<change>/.exploration.md`
- [x] 6.3 Implement the architect-prompt builder: includes the cached exploration in the prompt as ground truth, explicit "do not re-traverse the codebase" instruction
- [x] 6.4 Implement cache invalidation on `[r] redo this phase` at the explore pause: delete the cache and re-invoke `dd:code-explorer`
- [ ] 6.5 Add both cache paths (`<workdir>/.feature-exploration.md` and `<change>/.exploration.md`) to `.gitignore` via the consumer-repo extension protocol (template snippet)

## 7. Documentation

- [x] 7.1 Add `commands/feature.md` to the Top-level table in `commands/README.md` with the one-liner
- [x] 7.2 Add a "Feature skills" section to `skills/README.md` listing `feature-orchestrate` and `feature-clarify`
- [x] 7.3 Update `docs/skills-catalog.md` with the new Feature skills group
- [x] 7.4 Add an "End-to-end shortcut" subsection to `docs/workflow.md` after the existing per-phase walkthrough; explicitly note `/dd:feature` is a convenience, not a replacement

## 8. Tests

- [ ] 8.1 Fixture: a synthetic idea string and an empty-but-initialized Drydock repo; assert that `/dd:feature "<idea>"` produces (in order) a raw entry, a code-exploration cache, a GitHub issue, an OpenSpec change, a branch, a design.md, a tasks.md, commits per task, and a draft PR
- [ ] 8.2 Test: `feature.pause_after.design: true` causes the orchestrator to halt after architecture and emit the resume hint citing `/dd:build:design`
- [ ] 8.3 Test: mid-flow exit at phase 5 leaves the workspace recoverable via `/dd:build:design` (artifact present, no orphan state file)
- [ ] 8.4 Test: `feature-clarify` produces zero questions when the idea + codebase leave no ambiguity (assert via a fixture where the idea is "rename function `foo` to `bar`" with `foo` defined exactly once)
- [ ] 8.5 Test: `dd:code-explorer` is invoked exactly once per `/dd:feature` run (verify by counting Agent dispatches in test harness); architect dispatch on phase 6 references the cached exploration in its prompt
- [ ] 8.6 Test: `feature.idea_destination: skip` skips raw capture and starts the flow at issue creation
- [ ] 8.7 Test: invoking `/dd:feature` on a workspace with an active in-flow state resumes at the next pending phase rather than starting over
- [ ] 8.8 Test: `[r] redo this phase` at the explore pause deletes the cache and re-invokes the explorer
- [ ] 8.9 Test: `?` answer to a clarifying question appends the question to `<change>/design.md` § Open Questions and continues the flow

## 9. Verification

- [x] 9.1 Run `openspec validate add-feature-orchestrator --strict` and resolve any issues
- [ ] 9.2 Run all `lib/tests/test_*.sh` — all pass, including the new feature-related tests *(existing 31 tests pass with no regression; no new feature-related tests added — covered by deferred 8.x)*
- [ ] 9.3 Smoke test: in this drydock repo, run `/dd:feature "add a /dd:scratch command for ad-hoc notes"` and verify the full chain to draft PR
- [x] 9.4 Final grep across `commands/feature.md`, `skills/feature-orchestrate/`, `skills/feature-clarify/`, `lib/feature_state.sh`: zero matches for any client/product name

## 10. Archive

- [ ] 10.1 Once tests are green and the smoke test passes, run `/dd:ship:archive add-feature-orchestrator`
- [ ] 10.2 Sync deltas (`feature-orchestration` capability spec, `command-suite` and `skill-library` deltas) into `openspec/specs/`
