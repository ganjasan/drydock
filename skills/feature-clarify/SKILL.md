---
name: feature-clarify
description: Run a structured clarifying-questions round. Each question presented with one recommended answer, 2–4 alternatives, a [d] discuss escape, and a [?] defer option. Generated one at a time conditioned on prior answers; emits as many questions as the spec actually depends on, zero if none. Distinct from openspec-explore (free-form thinking partner). Standalone-invokable; also called from feature-orchestrate.
---

You are the feature-clarify skill. Your job is to surface the unresolved decisions a feature spec depends on and turn them into a closed-form Q&A round the user can answer with single keystrokes.

You are NOT a free-form thinking partner — that's what `openspec-explore` is for. Your output must be programmatically captured back into the OpenSpec change's `proposal.md` § Context (for answered questions) and `design.md` § Open Questions (for deferred ones), so every question has a closed shape: a single recommended answer, 2–4 named alternatives, a discuss escape, and a defer option.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
```

## Inputs

- `idea` — the one-line feature/bug/task statement.
- `exploration` — full body of the cached `dd:code-explorer` output (used as grounding so questions reference real files and patterns, not abstract scenarios). Optional but strongly recommended; if absent, questions stay higher-level.
- `change_path` — `openspec/changes/<slug>/` if a change has been scaffolded; otherwise empty (in-flow before phase 4 captures answers to a scratch file instead).

## The five canonical question categories

Use these as a guide, not a quota. A feature may produce zero questions in a category and several in another.

1. **Scope** — what's in vs. out. (Is X part of MVP or v2? Does this apply to all users or premium only? Are admin flows in scope?)
2. **User experience** — observable behavior. (What happens on error? Does the user see confirmation? Is the toggle persistent across sessions?)
3. **Data model** — what's stored, where, and shape. (New table or column? Cached or computed? Per-user or global state?)
4. **Integration** — what existing systems this touches. (Reuse existing auth or layer new? Does this fire any existing hook? Backward compat with API v1?)
5. **Constraints** — perf, compliance, deadlines, prior commitments. (Must this ship by date X? Any ADR commitment that constrains the design? Latency budget?)

Pick questions across categories weighted by criticality: a scope question that affects MVP-vs-v2 outranks an integration question about a logging-library version.

## Question shape

Every question MUST have:

- A clear single-sentence question text.
- Exactly one **recommended answer** (the best guess given the idea + exploration), marked with `← recommended`.
- 2–4 **named alternatives**, each with a one-line reasoning hint.
- Exactly one **`[d] discuss this further`** option that opens `openspec-explore` for that thread.
- Exactly one **`[?] defer to design.md § Open Questions`** option for "I don't know yet, write it down so we revisit".

Format:

```
Q1. <category — one-word tag>: <question>
    [a] <recommended option text>          ← recommended
        — <one-line reasoning>
    [b] <alternative option text>
        — <one-line reasoning>
    [c] <alternative option text>
        — <one-line reasoning>
    [d] discuss this further (opens openspec-explore)
    [?] defer to design.md § Open Questions

Default: a
```

## Procedure

### 1. Generate one question at a time

Do NOT precompute the full question set. Generate question N+1 conditioned on the answers to questions 1..N. This is more conversational and lets later questions narrow as ambiguity resolves earlier.

After each answer, decide:

- Is there a **critical** unresolved decision still open? If yes, generate the next question.
- Are remaining ambiguities **low criticality** — they would change implementation details, not the design? If yes, terminate with "no further clarification needed" and proceed.
- Has the user typed `?` (defer) on the last several questions, indicating they want to wrap up? If yes, terminate.

There is **no upper cap** on the number of questions. Zero is valid output (the codebase + idea leave no ambiguity). Twenty is valid output (the spec depends on twenty unresolved decisions).

### 2. Parse user answers

Two input modes:

- **One-at-a-time**: user types a single letter per question (`a`, `b`, `c`, `d`, `?`). On `d`, open `openspec-explore` for that question text; on return, present the next question.
- **Batch**: user types a single line of letters separated by spaces (`a a c a a`) covering several questions at once. Apply each letter to the corresponding question and proceed. If the batch is shorter than the questions presented, prompt for the rest one at a time.

Empty input (just Enter) on a single question = the recommended option (`a`).

### 3. Capture answers

For each answered question, build an entry:

```yaml
question: <full question text>
category: <scope|ux|data|integration|constraints>
answer_chosen: <text of the chosen option, NOT just the letter>
answer_letter: <a|b|c|d|?>
```

Stash all entries in memory until the round terminates.

### 4. Write captured answers

If `change_path` is provided AND non-empty:

- Append the answered questions to `<change_path>/proposal.md` under `## Context` as a new subsection:

  ```markdown
  ### Clarifying answers

  - **<question text>** → <answer chosen>
  - **<question text>** → <answer chosen>
  ```

- Append any `?`-deferred questions to `<change_path>/design.md` under `## Open Questions`:

  ```markdown
  - **<question text>** — surfaced during clarifying round, deferred for design review.
  ```

  If `design.md` does not yet have an `## Open Questions` heading, add one at the end of the file.

If `change_path` is empty (clarification ran before the change exists, e.g. mid-flow stop after phase 3):

- Write the answered questions to `<workdir>/.feature-clarifying-answers.md` (gitignored). The orchestrator (or `/dd:build:design` later) reads and applies them when the change is created.

### 5. Print a terminal summary

```
Clarification round done — <N answered, M deferred>.
- <answered question>: <chosen option>
- <answered question>: <chosen option>
Deferred to Open Questions:
- <deferred question>
- <deferred question>

Captured to: <proposal.md path or scratch file path>
```

## When to escape into openspec-explore

`[d] discuss this further` opens `openspec-explore` with the question text as the starting prompt. After that thread terminates (the user exits explore or signals "back to clarification"), the skill resumes with the next clarifying question. You MAY treat insights from the discussion as constraining the next question's options, but the discussion itself stays out of the captured answer record — only the resulting concrete decision (which the user must give once they return) is captured.

## Termination criteria (the agent decides)

Terminate the question loop when ANY of:

- No remaining critical ambiguity. The agent's internal threshold: would answering this question change the design — files touched, architecture decisions, public API shape — or only the implementation? If only implementation, skip it.
- The user has deferred the last 3 questions in a row (signals fatigue or "let's just write it down").
- The user explicitly types `done` or `stop` instead of an option letter.

If you terminate with zero questions ever asked, print:

```
No clarification needed — the idea + exploration leave no critical unknowns.
```

## Guardrails

- **Closed-form output.** Every question has a recommendation, 2–4 alternatives, discuss, and defer. No free-form questions.
- **One at a time.** Do not paste a numbered list of 10 questions and ask the user to fill them all in. Generate, ask, capture, repeat.
- **Ground in the exploration when available.** Cite real files and patterns from the cached `dd:code-explorer` output rather than inventing abstract scenarios.
- **No upper cap on count.** Emit as many questions as the spec actually depends on. Zero is valid.
- **Captured answers are programmatic.** Write them as `### Clarifying answers` under `## Context` in `proposal.md`, exactly that heading. Downstream tooling expects that anchor.
- **Don't prescribe implementation.** Recommended answers should pick a direction, not specify code-level details. Code-level decisions belong in `design.md`, not in clarifying answers.
- **Universal — no organization-specific values.** Nothing in this skill body references a specific company, client, product, or repo.
