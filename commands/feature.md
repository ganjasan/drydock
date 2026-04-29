---
description: End-to-end orchestrator — walks an idea from raw capture to draft PR, pausing at each phase boundary
argument-hint: "[<one-line idea>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, SlashCommand, Agent
---

Walk a single idea through the full Drydock workflow without re-typing every phase command. `/dd:feature` is a thin orchestrator over the existing `/dd:raw:*`, `/dd:plan:*`, `/dd:build:*`, and `/dd:ship:*` commands — it never reimplements their logic, it just sequences them and pauses at the checkpoints that matter.

If you want the per-phase entry points instead, they remain canonical: `/dd:raw:capture` → `/dd:plan:add` → `/dd:plan:promote` → `/dd:build:start` → `/dd:build:design` → `/dd:build:code` → `/dd:build:test` → `/dd:ship:pr`. `/dd:feature` is the convenience.

## Procedure

Load merged Drydock config and the feature-state helper:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh";        dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/feature_state.sh"
```

### 1. Resolve entry mode

`$ARGUMENTS` is an optional one-line idea. Resolve mode in this order:

1. `$ARGUMENTS` is non-empty → **new flow** with that idea string.
2. `$ARGUMENTS` is empty AND `dd_feature_position` returns a non-`none` phase → **resume** at the next pending phase. Print the detected phase and a one-line summary of what was last completed.
3. `$ARGUMENTS` is empty AND no in-flow state is detected → prompt the user for the idea before continuing.

### 2. Delegate to the orchestrator skill

Invoke `skills/feature-orchestrate` with the resolved idea string and a flag indicating new vs. resume. The skill encapsulates the phase walk so this command stays a thin shell — see `skills/feature-orchestrate/SKILL.md` for the full sequence.

The skill is also standalone-invokable as `/feature-orchestrate` for users who want to run the orchestration without going through this wrapper.

### 3. On exit, print the resume hint

If the user stops mid-flow at a pause, the orchestrator emits the resume hint naming the per-phase command that picks up the next step (e.g. `Resume with: /dd:build:design`). This command does not add to that — it just exits with the orchestrator's status code.

If the flow runs to completion (a draft PR is opened), the orchestrator emits the terminal report.

## Output

When new:

```
/dd:feature → "<idea string>"
Starting at phase 1: capture idea.
```

When resuming:

```
/dd:feature → resume
Detected: phase 5 (architecture). Last artifact: openspec/changes/<slug>/design.draft.md.
Continuing at phase 6: architecture review.
```

The skill prints per-phase output beyond this header.

## Guardrails

- This command MUST NOT inline phase logic. Every phase delegates to the corresponding existing command/skill (`raw-capture`, `/dd:plan:add`, `/dd:plan:promote`, `/dd:build:start`, `/dd:build:design`, `/dd:build:code`, `/dd:build:test`, `/dd:ship:pr`) or to the explicitly-named agents (`dd:code-explorer` on phase 2, `dd:code-architect` on phase 6).
- This command MUST NOT skip pause points except where `feature.pause_after.<phase>: false` is configured. Defaults pause at `idea`, `clarify`, `design`, and `pr`.
- This command MUST NOT auto-merge a PR, auto-archive a change, or auto-cut a release. The flow ends at "draft PR opened"; everything beyond is human review and the existing `/dd:ship:archive` / `/dd:ship:release` commands.
- This command MUST NOT write a phase-state file. Phase position is derived from artifacts via `dd_feature_position`.
- Stepping out at any pause MUST leave the workspace recoverable — every artifact already produced (raw entry, issue, change, branch, design draft) survives, and the resume hint cites the per-phase command that resumes.
