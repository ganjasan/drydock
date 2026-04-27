## Context

Drydock's `commands/`, `skills/`, and `agents/` directories contain only READMEs today. The existing implementation of this methodology lives at `/home/artem/Documents/Projects/Apilize/apilize-hub/plugins/apz/` (~30 command files, 3 agents, embedded helpers in `lib/`). APZ is deeply coupled to Apilize: config.yaml hardcodes GitHub Project #2, the `area_to_repo` table names Apilize repos, command bodies reference paths like `apilize-hub/requirements/vision/`, and the raw-ingestion commands assume `apilize-hub/raw/_incoming/`. The `docs/migration-from-apz.md` roadmap already declares the intended end state but has no corresponding implementation.

Stakeholders:
- **Drydock maintainer (Artem)** — needs the port to be reviewable in layers and to support dogfooding mid-flight.
- **Future APZ** — after this port, APZ must be able to install Drydock and layer its Apilize-only commands on top without duplication.
- **External users** — first real consumers of Drydock v0.1; they have no `apilize-hub/` and must be able to install the plugin and run `/dd:status` in any repo.

Constraints:
- Dogfood principle (`CLAUDE.md`): every behavior change in this port itself must go through an OpenSpec change — this one.
- "No backward-compatibility shims for APZ command names" rule: the port is a rename, not an alias layer.
- "No ties to a specific SaaS, company, or domain": every Apilize default must become either a removed value or a configurable knob with a neutral default.

## Goals / Non-Goals

**Goals:**
- Stand up a working `/dd:*` command suite that matches `docs/workflow.md` and `docs/skills-catalog.md` end-to-end.
- Make every Apilize-specific value (project ID, labels, paths, `area_to_repo`) configurable via `config.yaml`, with sensible universal defaults when the file is absent.
- Make skills standalone-invokable so a consumer can call `/drydock:adr` without going through `/dd:req:adr`, per `skills-catalog.md`.
- Ship a valid Claude Code `plugin.json` so the plugin is installable and its components auto-discovered.
- Preserve the procedural content of each APZ command (the body of the prompt is the product); only substitute paths, IDs, and labels.

**Non-Goals:**
- Port `/apz:raw:*` (raw-content ingestion). Stays in APZ; raw inbox semantics are Apilize-hub-specific.
- Port `/apz:ship:conformance` and `/apz:ship:parity`. These are Apilize-Protocol-specific test gates.
- Refactor APZ to depend on Drydock. That is a follow-up after v0.1 ships.
- Introduce new functionality beyond what APZ already does. This is a port, not a redesign. Genuinely new ideas must go through their own OpenSpec change.
- Provide a Python/TS SDK or automation API. Drydock is, for v0.1, a prompt suite only.

## Decisions

### D1. Command bodies are authored fresh, not copy-pasted

Each `/dd:*` command file is rewritten from the corresponding APZ command, replacing Apilize-specific references, rather than text-substituted. Rationale: `sed`-based substitution on multi-hundred-line prompts produces awkward results (stray mentions, broken sentences). A fresh pass forces the author to notice implicit Apilize assumptions. Alternative considered: automated rewrite via a script. Rejected because the set of substitutions is fuzzy (some references to "Apilize" are in sentences that need restructuring, not swapping).

### D2. Configuration via a single `config.yaml` file in the plugin root

Everything configurable lives in one `config.yaml` at the plugin root, discovered via `${CLAUDE_PLUGIN_ROOT}/config.yaml`. If the file is absent, commands fall back to **built-in defaults** that are plausible for any git repo (no project integration, single-repo workspace, branch naming `feature/<issue>-<slug>`, worktree directory `.worktrees/`). Alternative considered: multiple configs (e.g. `github.yaml`, `workspace.yaml`). Rejected because APZ's experience shows one file is easier to reason about and document, and consumers tend to override only a handful of values.

### D3. Skill directory layout mirrors Claude Code conventions; command files wrap skills thinly

Each skill is `skills/<name>/SKILL.md` with optional `templates/` and `examples/` subdirectories. Command files (`commands/req/adr.md` etc.) are thin wrappers whose primary job is argument parsing and path resolution; the actual prompt body lives in the skill. This means `/dd:req:adr` and a standalone `/adr` skill invocation produce the same output. Alternative considered: inline skill contents into command files. Rejected because it blocks the standalone-invocation goal and duplicates the prompt in two places.

### D4. Ship minimal stubs for agents; defer deep specialization

The five ported agents (`code-reviewer`, `code-explorer`, `code-architect`, `traces-linter`, `release-coordinator`) are created with frontmatter + a compact system prompt that captures the intent from APZ. Three of them (`code-reviewer`, `code-explorer`, `code-architect`) mirror existing Claude Code built-in agents of similar names; for those we explicitly document the difference ("Drydock-flavored: applies Wiegers traceability check") rather than re-implement from scratch. Alternative considered: skip the port and rely on Claude Code built-ins. Rejected because `traces-linter` and `release-coordinator` have no built-in equivalent, and consistent naming across the five is easier to document.

### D5. Spec capabilities are coarse (4 specs), not per-command (30+ specs)

One spec per architectural surface: `command-suite`, `skill-library`, `agent-library`, `plugin-manifest`. Alternative considered: one spec per command (`spec/dd-status/spec.md`, `spec/dd-req-adr/spec.md`, …). Rejected because the core behaviors that need to be specified at the requirements level — naming conventions, configuration discovery, guardrails, standalone invocability — apply uniformly across a family. Per-command requirements would be 80% copy-paste of the family-level invariant plus 20% command-specific body, and the specs would drift. Command-specific procedural content belongs in the command file itself.

### D6. Sequencing: top-level → requirements → build → ship → plan → manifest

Tasks land in phases so intermediate states are usable. Rationale:

1. `plugin.json` + `/dd:status` + `/dd:next` first — smallest self-contained slice, proves the plugin loads.
2. `/dd:req:*` — purely local (no GitHub calls), easy to validate in isolation.
3. `/dd:build:*` — depends on `openspec` CLI which is already available; independent of `/dd:plan:*`.
4. `/dd:ship:*` — needs `gh` but no Project integration.
5. `/dd:plan:*` — touches GitHub Projects v2, the most config-heavy part. Landing it last means earlier commands are tested without this complexity.
6. Agents land alongside whichever phase first invokes them (`code-explorer` in build, `traces-linter` in ship).

Alternative considered: full horizontal port (all commands, then all skills, then all agents). Rejected because it produces long stretches where nothing works end-to-end and review becomes all-or-nothing.

## Risks / Trade-offs

- [Risk] Scope creep — porting surfaces genuine bugs in the APZ version (hardcoded usernames, stale references, dead code paths). → **Mitigation**: fix in place during port only if the fix is one line and mechanical; anything larger gets its own backlog item and does not block this change.
- [Risk] Config defaults leak Apilize assumptions — e.g. defaulting `branch_naming` to `feature/<issue>-<slug>` assumes GitHub Issues exist. → **Mitigation**: call out each default in `config.yaml.example` with a comment explaining what it assumes, so consumers can opt out.
- [Risk] Skills become unusable standalone because they assume Drydock-specific paths (`requirements/adr/`) that a consumer may not have. → **Mitigation**: skills validate their required paths on entry and offer to create them, rather than failing silently. Covered by a scenario in the `skill-library` spec.
- [Risk] Five new agents with overlapping responsibilities confuse users (`code-reviewer` vs Claude Code's built-in `code-reviewer`). → **Mitigation**: prefix Drydock agents with `drydock:` namespace where Claude Code honors it; document the difference in `agents/README.md`.
- [Trade-off] Landing the port incrementally means intermediate commits leave the plugin in partially-working states. Accepted because the alternative — one giant PR — is un-reviewable. Each phase boundary is a merge point.
- [Trade-off] Ignoring APZ `raw/*` commands means Drydock has no story for capturing external signals (meetings, emails). Accepted for v0.1; a future change can introduce a generic signal-capture abstraction, but it needs its own design pass.

## Migration Plan

This port has no runtime migration — Drydock v0.1 is a green-field release. For authors of APZ:

1. After Drydock v0.1 lands, APZ opens its own OpenSpec change to refactor `apilize-hub/plugins/apz/` into a thin layer that depends on Drydock.
2. APZ keeps only: raw-ingestion commands (`/apz:raw:*`), conformance/parity (`/apz:ship:conformance`, `/apz:ship:parity`), the `area_to_repo` override for Apilize, and any client-specific workflows.
3. All other APZ commands become aliases over their `/dd:*` equivalents and are deprecated with a 1-cycle warning period.
4. `docs/migration-from-apz.md` in this repo becomes authoritative; the same document is mirrored read-only in apilize-hub to guide APZ-native users.

Rollback: if the port proves unworkable mid-flight, the phase-by-phase sequencing (D6) means revert is a single `git revert` per phase, not a monolithic undo.

## Open Questions

- **Q1**: Does `plugin.json` require an `author` or `license` field for auto-discovery to work, or are those optional? — Resolve by reading Claude Code's plugin spec during implementation of phase 1.
- **Q2**: Should `/dd:plan:promote` fail loudly or silently when `config.yaml` has no `area_to_repo` entry matching the issue's Area? — Tentative: fail loudly and prompt the user to add a mapping. Confirm when writing the `plan` spec scenarios.
- **Q3**: `openspec` CLI version compatibility — is there a minimum version we assume? — Document the assumed version in `plugin.json` or `config.yaml.example` once the port is compiling. For now, match whatever APZ currently uses.
