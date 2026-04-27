## 1. Config loader

- [x] 1.1 Refactor `lib/config.sh` to perform three-layer merge: plugin-root → user-level (`~/.drydock/config.yaml`) → per-repo (`<repo>/.drydock/config.yaml`); maps merge key-by-key, lists replace wholesale
- [x] 1.2 Materialize merged config to a JSON tempfile per command invocation; export path as `DRYDOCK_CONFIG_PATH`
- [x] 1.3 Detect `yq` presence; fail fast with a clear install message when missing
- [x] 1.4 Ensure tempfile cleanup on command completion (success, abort, hook failure) via shell trap
- [x] 1.5 Add `lib/tests/test_config_merge.sh` covering: per-repo wins, user-level wins, plugin-root wins, list replacement, map merge, missing layers, missing all layers
- [x] 1.6 Reject configuration from alternate locations (`<repo>/drydock.yaml`, `<repo>/.drydock.yaml`); add a test scenario

## 2. Hook dispatcher

- [x] 2.1 Create `lib/hooks.sh` with `dd_hook_invoke <event> [<extra-payload-json>]` that locates `<repo>/.drydock/hooks/<event>.sh`, builds JSON payload (event, repo_path, config_path, plus extra), pipes via stdin, captures exit code
- [x] 2.2 Implement skip semantics: silent skip on missing file; one-line warning on present-but-not-executable file
- [x] 2.3 Implement abort semantics by category: `pre-*` aborts caller on non-zero; `post-*` warns and continues; `session-start` warns and continues
- [x] 2.4 Add `lib/tests/test_hooks.sh` covering: missing hook skipped, non-exec hook warns, pre-hook abort propagates exit code, post-hook warns but does not abort, payload schema includes required fields

## 3. Command updates — read merged config

- [x] 3.1 Update `commands/status.md` to read via the merged loader (no direct `${CLAUDE_PLUGIN_ROOT}/config.yaml` lookup)
- [x] 3.2 Update `commands/next.md` likewise
- [x] 3.3 Update all `commands/req/*.md` to read via the merged loader
- [x] 3.4 Update all `commands/plan/*.md` to read via the merged loader
- [x] 3.5 Update all `commands/build/*.md` to read via the merged loader
- [x] 3.6 Update all `commands/ship/*.md` to read via the merged loader
- [x] 3.7 Grep `commands/` for `CLAUDE_PLUGIN_ROOT/config.yaml` references; assert zero matches outside `lib/config.sh`

## 4. Command updates — invoke lifecycle hooks

- [x] 4.1 Update `commands/ship/pr.md` to call `dd_hook_invoke pre-pr` with payload `{branch, commits}` before opening the PR; abort on non-zero
- [x] 4.2 Update `commands/ship/release.md` to call `dd_hook_invoke pre-release` before any other release work; abort on non-zero
- [x] 4.3 Update `commands/ship/release.md` to read `release.gates` from merged config, dispatch each entry as a slash-command via Claude Code, abort on non-zero gate; named-not-found fails loudly
- [x] 4.4 Update `commands/ship/archive.md` to call `dd_hook_invoke post-archive` with payload `{change_slug}` after archive completes; warn on non-zero, do not roll back
- [x] 4.5 Add or update `hooks/session-start` integration so Claude Code SessionStart fires `dd_hook_invoke session-start`; warn on non-zero, do not abort

## 5. Templates skeleton

- [x] 5.1 Create `templates/extension/config.yaml` with all top-level keys present and commented (paths, github, area_to_repo, release, worktree, raw [placeholder]); zero references to any organization/project name
- [x] 5.2 Create `templates/extension/hooks/pre-pr.sh.example` (e.g. content-guard sketch, exits 0)
- [x] 5.3 Create `templates/extension/hooks/pre-release.sh.example`
- [x] 5.4 Create `templates/extension/hooks/post-archive.sh.example`
- [x] 5.5 Create `templates/extension/hooks/post-capture.sh.example`
- [x] 5.6 Create `templates/extension/hooks/session-start.sh.example`
- [x] 5.7 Verify templates pass the universality grep (no client/project names)

## 6. Documentation

- [x] 6.1 Write `docs/extension-model.md` — sections: Overview, Configuration schema, Three-layer merge order with worked example, Hook lifecycle table (event → trigger → payload → exit semantics), Command-reference contract, End-to-end example
- [x] 6.2 Update `config.yaml.example` at plugin root: add header comment clarifying that this file is now "global plugin defaults" and pointing at `docs/extension-model.md` for per-repo overrides
- [x] 6.3 Cross-check that `docs/methodology.md`, `docs/workflow.md`, and `README.md` references to extension-model resolve to the new doc

## 7. Verification

- [x] 7.1 Run `openspec validate drydock-extension-model --strict` and resolve any issues
- [x] 7.2 Run all `lib/tests/test_*.sh` — all pass (16/16)
- [x] 7.3 Smoke-test in this repo: create `<drydock>/.drydock/config.yaml` with a single key override; verify a command observes it via merged loader
- [x] 7.4 Smoke-test hook dispatch: drop a `pre-pr.sh` returning non-zero in this repo; verify `/dd:ship:pr` aborts cleanly
- [x] 7.5 Smoke-test command-reference dispatch: declare `release.gates: [/dd:build:test]` in this repo; dry-run `/dd:ship:release` and confirm the gate runs
- [x] 7.6 Confirm no `${CLAUDE_PLUGIN_ROOT}/config.yaml` direct reads remain in command files (final grep)

## 8. Dogfood

- [x] 8.1 Migrate this drydock repo's own configuration (if any) from plugin-root to `<drydock>/.drydock/config.yaml`
- [x] 8.2 Add a minimal `<drydock>/.drydock/hooks/pre-pr.sh` that asserts `traces_to` frontmatter is present in any added/modified ADR or use-case file (uses existing `lib/frontmatter.sh`)
- [ ] 8.3 Run `/dd:ship:pr` end-to-end on this change to confirm the hook protocol works on the dogfood repo *(deferred to an actual PR for this change)*
