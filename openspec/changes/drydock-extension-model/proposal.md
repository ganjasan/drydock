## Why

Drydock v0.2 commits to one plugin for all projects with full APZ retirement (see [ADR-0004](../../../requirements/adr/0004-universal-workflow-and-project-extensions.md)). This requires a well-defined surface where each consuming repo expresses its own specifics — paths, sources, filters, gates, routing, content guards — without forking the plugin or maintaining a sibling plugin. Today's plugin code resolves `config.yaml` at `${CLAUDE_PLUGIN_ROOT}/config.yaml` (a global, single-tenant lookup) and has no notion of project-local hooks or referenceable project commands. That gap blocks the three downstream changes (`add-raw-phase`, `config-driven-paths-and-gates`, `retire-apz`), so this change has to land first.

## What Changes

- **NEW** Per-repo configuration overlay at `<repo>/.drydock/config.yaml` with documented schema (paths, raw sources, github, area-to-repo, release gates, multi-repo, worktree, frontmatter rules). `${CLAUDE_PLUGIN_ROOT}/config.yaml` becomes a global default fallback only.
- **NEW** Lifecycle-hook protocol at `<repo>/.drydock/hooks/<lifecycle-point>.sh` invoked by Drydock commands at well-defined moments. Initial set: `pre-pr.sh`, `pre-release.sh`, `post-capture.sh`, `post-archive.sh`, `session-start.sh`. Hook discovery is by file presence; non-zero exit aborts the operation (or warns, depending on point).
- **NEW** Command-reference contract: `config.yaml` keys like `release.gates` accept slash-name strings (e.g. `/dd:build:test`, `/conformance`, `/parity`); Drydock invokes referenced commands via Claude Code's standard slash-command dispatch, supporting both built-in `/dd:*` commands and project-local commands at `<repo>/.claude/commands/<name>.md`.
- **NEW** `lib/config.sh` rewritten to merge configuration from three layers (with later layers overriding earlier): plugin-root default → user-level `~/.drydock/config.yaml` (if present) → per-repo `<repo>/.drydock/config.yaml`. All commands read merged config through this loader.
- **NEW** `docs/extension-model.md` documenting the schema, hook lifecycle table, command-reference contract, and migration notes.
- **NEW** `templates/extension/` skeleton: `config.yaml` template with all keys commented and example hook scripts users can copy.
- **MODIFIED** All `/dd:*` commands that currently read configuration are updated to read from the merged loader, not directly from `${CLAUDE_PLUGIN_ROOT}/config.yaml`.
- **MODIFIED** `/dd:ship:pr`, `/dd:ship:release`, `/dd:ship:archive`, and (after `add-raw-phase`) `/dd:raw:capture` invoke the corresponding lifecycle hook if present.
- **BREAKING** The `${CLAUDE_PLUGIN_ROOT}/config.yaml` location remains valid as a global default but is no longer the per-project source of truth. No projects on the v0.1 config layout exist outside Apilize-hub (and Apilize migrates as part of `retire-apz`), so user impact is contained to a documented one-time move.

## Capabilities

### New Capabilities

- `extension-model`: per-repo overlay at `<repo>/.drydock/{config.yaml,hooks/}`; configuration schema and merge order; lifecycle-hook protocol with the initial five hook points; command-reference contract for slash-name invocation from config (built-in and project-local); contract documented in `docs/extension-model.md`.

### Modified Capabilities

- `command-suite`: every Drydock command that reads configuration MUST do so via the merged config loader, not via direct `${CLAUDE_PLUGIN_ROOT}/config.yaml` lookup. Ship commands (`pr`, `release`, `archive`) gain hook invocation contracts at their respective lifecycle points.

## Impact

- **Code:** `lib/config.sh` rewritten; new `lib/hooks.sh` for hook dispatch; `commands/ship/{pr,release,archive}.md` updated; status/next commands read config via new loader.
- **Docs:** new `docs/extension-model.md`; `docs/methodology.md` and `docs/workflow.md` already updated in advance to reference the new model.
- **Templates:** new `templates/extension/config.yaml` and `templates/extension/hooks/*.sh.example` files.
- **Specs:** new `extension-model` spec; `command-suite` spec extended with config-loader and hook-invocation requirements.
- **Tests:** verify three-layer config merge precedence; verify hook invocation and exit-code handling; verify command-reference dispatch for both `/dd:*` and project-local commands.
- **Downstream changes unblocked:** `add-raw-phase` (uses `paths.raw_root`, `raw.<source>.*`, `post-capture.sh`); `config-driven-paths-and-gates` (uses `release.gates`, `area_to_repo`); `retire-apz` (Apilize-hub migration relies on this overlay existing).
- **Breaking-change scope:** only the configuration file location semantics. No command-name changes, no removed APIs. APZ users migrate as part of `retire-apz`, not this change.
