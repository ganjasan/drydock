## Context

Drydock v0.1 resolves configuration via `${CLAUDE_PLUGIN_ROOT}/config.yaml` — a single global file living next to the plugin code. There are no lifecycle hooks and no notion of project-specific commands referenceable from configuration. ADR-0004 commits the project to a single-plugin model where every consuming repo carries its own specifics. Three downstream changes (`add-raw-phase`, `config-driven-paths-and-gates`, `retire-apz`) all need a per-repo overlay, hook protocol, and command-reference contract to land first.

The constraint set:

- **One plugin only.** No sibling plugins for project specifics. Everything either lives in Drydock (universal) or in `<repo>/.drydock/` and `<repo>/.claude/commands/` (project-local).
- **No regressions for the only existing consumer (Apilize-hub) until `retire-apz` ships.** The plugin-root config file must keep working as a fallback during the transition.
- **Plain shell + markdown.** Drydock commands are markdown invoking shell helpers; no new runtime is allowed.
- **Hook contract must be honest about trust boundaries.** Hooks run user code in the user's repo; Drydock does not sandbox. The contract is: well-defined input on stdin, exit code semantics by hook category.

## Goals / Non-Goals

**Goals:**

- A documented per-repo overlay location at `<repo>/.drydock/config.yaml` with a stable schema covering paths, GitHub, area routing, release gates, multi-repo, worktree, and a placeholder for `raw.*`.
- A three-layer config merge (plugin defaults → user-level → per-repo) with deterministic precedence and merge semantics.
- A lifecycle-hook protocol with five initial points: `pre-pr`, `pre-release`, `post-archive`, `post-capture`, `session-start`.
- A command-reference contract: slash-command names in `config.yaml` resolve via Claude Code's native dispatch and address both built-in `/dd:*` and project-local `<repo>/.claude/commands/*`.
- `docs/extension-model.md` as the human-facing documentation of the above.
- Updated `lib/config.sh` plus a new `lib/hooks.sh`, with the rest of the plugin (commands) routed through them.

**Non-Goals:**

- Implementing `/dd:raw:*` commands or the `raw.*` config block beyond a documented placeholder. That is the `add-raw-phase` change.
- Defining the actual gates a real release should run. That is `config-driven-paths-and-gates`.
- Deleting any APZ artifacts. That is `retire-apz` (in the Apilize-hub repo, not Drydock).
- A plugin DSL or sandboxed hook execution model. Hooks are user shell scripts.
- Backward compatibility with multiple historical config schemas. v0.1's single config file is the only prior format and migrates trivially.

## Decisions

### D1. Overlay location: `<repo>/.drydock/`, not `.drydock.yaml` or root-level files

A hidden directory groups configuration, hooks, and any future schemas under one well-known path. Parallels `.claude/`, which Claude Code already uses. Single-file alternatives (e.g. `<repo>/drydock.yaml` at root) were rejected: hooks need a directory anyway, and a single-file approach would force a second well-known location for them.

### D2. Three-layer merge: plugin-root → user-level → per-repo (later wins)

| Layer | Path | Use |
|---|---|---|
| Plugin-root | `${CLAUDE_PLUGIN_ROOT}/config.yaml` | Documented universal defaults shipped with Drydock |
| User-level | `~/.drydock/config.yaml` *(optional)* | Personal overrides across all repos a single dev works in |
| Per-repo | `<repo>/.drydock/config.yaml` | Checked-in project specifics — wins |

Map keys are merged key-by-key; lists are replaced wholesale. List-merge would be ambiguous for ordered things like `release.gates`, where intent is usually "I want exactly this sequence." Map-merge matches typical user expectation for things like `area_to_repo`. This precedence is documented; no surprises.

Alternatives considered:

- **Single-file (per-repo only).** Rejected: makes shipping universal defaults hard, forces every consumer to copy boilerplate.
- **Plugin-root wins (defaults override).** Rejected: wrong inversion of authority — the project knows itself best.
- **List append rather than replace.** Rejected: ambiguous for ordered lists, no good way to "remove an item" from a list once it's appended.

### D3. Hook discovery by file presence, no registration

A script at `<repo>/.drydock/hooks/<name>.sh` that is executable runs at the corresponding lifecycle event. Missing or non-executable files are silently skipped. No `hooks.json`, no manifest, no registration step.

This matches Drydock's broader convention (commands and skills are auto-discovered from filesystem layout). It also keeps the hook contract narrow: there is no metadata to keep in sync.

### D4. Hook contract: JSON on stdin, exit code carries pass/fail, abort semantics by hook category

Each hook receives a JSON payload on stdin describing the lifecycle context (event name, repo path, change slug if applicable, branch, commit list — schema documented in `extension-model.md` and stable within v0.x).

Exit-code semantics:

- **`pre-*` hooks** — non-zero exit aborts the operation. The user's hook is a guard; it has authority to refuse.
- **`post-*` hooks** — non-zero exit is reported as a warning but does **not** roll back. The operation already happened; rolling back is out of scope and would create inconsistent state.
- **`session-start`** — non-zero exit is reported and Claude Code's session continues. (Aborting Claude Code itself from a Drydock hook is the wrong scope.)

This mirrors how Claude Code's native PreToolUse/PostToolUse hooks are framed (pre = guard, post = observer), kept consistent so users build correct mental models.

Alternatives considered:

- **Hook receives env vars instead of stdin.** Rejected: env-var encoding for nested data (commit list) is awkward and lossy.
- **Hook timeout enforced by Drydock.** Rejected: hook timing is the user's domain. They know their network calls.
- **Sandboxed execution.** Rejected: hooks are user code in the user's repo; trust is implicit. Sandboxing would be performative.

### D5. Command-references: slash-name strings dispatched via Claude Code's native mechanism

`release.gates: [/dd:build:test, /conformance]` is a list of slash-command names. Each entry is invoked via Claude Code's standard slash-command dispatch. This addresses both built-in commands shipped by Drydock and project-local commands at `<repo>/.claude/commands/<name>.md`, with no extra resolution code in Drydock.

If a referenced command does not resolve, the operation aborts with a clear "command not found" error rather than skipping silently — silent skips for misspelled gates would be a footgun.

Alternatives considered:

- **Drydock-internal command registry.** Rejected: duplicates Claude Code, breaks for project-local commands.
- **Hook script as gate.** Rejected: gates are first-class user-visible operations; representing a multi-step test run as a hook script would obscure intent. Plus, a `/dd:build:test` gate already exists as a slash command.
- **Inline shell strings (`gates: ["pytest tests/"]`).** Rejected: pulls authority away from the reusable command surface; harder to standardize across repos.

### D6. Loader implementation in shell (`lib/config.sh`), with `yq` for YAML reads

Drydock commands are markdown invoking shell. The loader stays in shell. Config files are parsed with `yq` (already a Drydock prerequisite implicitly via `gh` JSON outputs and frontmatter parsing in `lib/frontmatter.sh`).

The merged result is materialized into a derived JSON blob in a temp file (`/tmp/drydock-config-<pid>.json`) for the duration of a command, and queried via `jq`. This avoids re-merging on every key access and gives a single canonical form to test against.

Alternatives considered:

- **Pure-bash YAML parser.** Rejected: fragile, no partial support for anchors/multi-doc.
- **Re-implement merge in Python.** Rejected: introduces a runtime dependency for a 50-line shell function.

### D7. Initial hook set: pre-pr, pre-release, post-archive, post-capture, session-start

Chosen because each maps to a real APZ-equivalent the team has already used in production:

| Hook | Equivalent in APZ today | Drydock invoker |
|---|---|---|
| `pre-pr` | `public-ready-guard.sh` | `/dd:ship:pr` |
| `pre-release` | (new) | `/dd:ship:release` |
| `post-archive` | (new — was a manual step) | `/dd:ship:archive` |
| `post-capture` | `frontmatter-lint.sh` | `/dd:raw:capture`, `/dd:raw:ingest-*` *(once `add-raw-phase` ships)* |
| `session-start` | `session-status.sh` | Claude Code SessionStart event |

`post-capture` is wired up in this change at the protocol level (the spec defines it), but no command actually invokes it until `add-raw-phase` lands `/dd:raw:capture`. That is intentional: the protocol can be defined ahead of its first invoker.

Additional points (e.g. `pre-archive`, `post-pr`) are deliberately deferred — adding hooks later is forward-compatible; removing them later breaks consumer repos.

## Risks / Trade-offs

- **Hook names become a stability surface.** → Ship a small initial set, document each, and treat additions as the only allowed change in v0.x. Renames or removals require a major version.
- **Command-reference dispatch depends on Claude Code's slash mechanism staying stable.** → Document the contract precisely in `extension-model.md`; depend only on the documented public interface; reach out if Claude Code semantics change.
- **`yq` may not always be installed.** → Detect presence in `lib/config.sh`; if missing, fail fast with a clear install message rather than silently using built-in defaults.
- **Three-layer merge is more code to test.** → Single test file in `lib/tests/` covers all merge scenarios using temp-dir fixtures.
- **Per-repo config encourages copy-paste of large boilerplate across repos.** → Mitigate via the `templates/extension/` skeleton and via the user-level layer (`~/.drydock/config.yaml`) for cross-repo personal defaults.
- **The plugin-root config keeps working as a fallback.** → That is intentional during the v0.1 → v0.2 transition. Apilize-hub will move off it as part of `retire-apz`. After that, plugin-root config is purely "shipped defaults" — no real consumer relies on it for project specifics.

## Migration Plan

This change is internal infrastructure. Migration of the only current consumer (Apilize-hub) happens in `retire-apz`, not here.

For the Drydock repo itself:

1. Land `lib/config.sh` rewrite and `lib/hooks.sh` with full test coverage.
2. Update each command that reads config to route through the new loader. Each command edit is a separate commit (small, reviewable).
3. Add `docs/extension-model.md` with schema, hook table, command-reference contract, and end-to-end example.
4. Add `templates/extension/` skeleton. Do not bundle Apilize specifics.
5. Update `config.yaml.example` at the plugin root to reflect that it is now "global defaults" and to point at `extension-model.md` for per-repo overrides.

Rollback strategy: if the merged loader misbehaves, the plugin-root-only path is one-line reversible (`config.sh` checks per-repo first; revert means skipping that step). No data is moved or deleted, so rollback has no data-loss risk.

## Open Questions

- **Should `~/.drydock/config.yaml` (user-level) ship in v0.2 or wait?** — Decision: ship it in this change. The merge code already has the layer; documenting and supporting one more file is essentially free, and personal cross-repo overrides are a clear use case (e.g. a developer who always wants `worktree.enabled: true`).
- **What is the JSON payload schema for each hook?** — Defined in `docs/extension-model.md` as part of this change. Initial fields per hook documented in the spec scenarios.
- **Should hooks be allowed to read merged config themselves?** — Yes: the JSON payload includes a `config_path` pointing at the materialized merged config tempfile, so hooks can inspect effective configuration without re-merging. Documented in `extension-model.md`.
- **Does `templates/extension/` belong in this change or in `add-raw-phase`?** — In this change. It is the canonical example of the extension model. `add-raw-phase` will extend it with `raw.*` keys.
