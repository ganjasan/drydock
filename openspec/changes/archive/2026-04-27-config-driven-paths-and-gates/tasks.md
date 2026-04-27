## 1. Path-resolution helper

- [x] 1.1 Create `lib/paths.sh` exposing `dd_path`, `dd_branch_name`, `dd_worktree_dir` per design D1
- [x] 1.2 Implement defaults baked into the helper (matching documented v0.1 layout) so undeclared keys behave as today
- [x] 1.3 Token substitution in `dd_branch_name` and `dd_worktree_dir`: support `<issue-id>` and `<slug>` only; reject unknown tokens with a clear error
- [x] 1.4 Add `lib/tests/test_paths.sh` covering: every `dd_path` variant under default config, under per-repo overrides, with absolute paths, with `.` for raw_root, missing-key fallbacks
- [x] 1.5 Add tests for `dd_branch_name` and `dd_worktree_dir` token substitution and unknown-token rejection

## 2. Command updates — paths

- [x] 2.1 Update every command in `commands/req/` to use `dd_path requirements_subdir <name>` for output destinations
- [x] 2.2 Update every command in `commands/build/` to use `dd_path openspec_changes` and `dd_path openspec_specs`
- [x] 2.3 Update `commands/build/start.md` to use `dd_branch_name` and `dd_worktree_dir`
- [x] 2.4 Update every `commands/raw/*.md` (after `add-raw-phase` lands) to use `dd_path raw_root` and `dd_path raw_subdir <name>`
- [x] 2.5 Update `commands/status.md` and `commands/next.md` to use the helper for any path checks
- [x] 2.6 Audit grep over `commands/` for path-like literals outside markdown blocks; fix any leakage

## 3. area_to_repo resolution

- [x] 3.1 Create `lib/area_routing.sh` exposing `dd_resolve_area <area>` returning either the absolute path or an error code with diagnostic
- [x] 3.2 Implement the five edge cases per design D2 / spec
- [x] 3.3 Update `commands/plan/promote.md` and `commands/build/start.md` to call `dd_resolve_area` and handle the error path with a fail-loud message offering to add the mapping
- [x] 3.4 Add `lib/tests/test_area_routing.sh` covering: unset, missing area, `.` value, absolute, relative

## 4. Multi-repo release coordination

- [x] 4.1 Update `agents/release-coordinator.md` to require `release.repos` ≥ 2 entries; document the trigger criterion in the agent description
- [x] 4.2 Implement Kahn's-algorithm topological sort with alphabetical tie-break in the agent prompt or in a helper invoked by it
- [x] 4.3 Implement cycle detection with abort-before-side-effects semantics
- [x] 4.4 Implement downstream version-pin propagation: after a repo bumps version, the dependent repo's manifest reference is updated to the new version
- [x] 4.5 Update `commands/ship/release.md` to invoke the agent iff `release.repos` ≥ 2; otherwise run single-repo flow unchanged
- [x] 4.6 Add fixture-level test: 3-repo `[a, b<-a, c<-a]` produces order `[a, b, c]`; 2-repo cycle aborts cleanly

## 5. github.project_fields opt-in setting

- [x] 5.1 Create `lib/gh_project.sh` helper exposing `dd_project_field_set <field-name> <value>` that no-ops when the field is unconfigured
- [x] 5.2 Update `commands/plan/add.md`, `commands/plan/triage.md`, `commands/plan/promote.md` to call the helper for status/priority/phase/area
- [x] 5.3 Add `/dd:status` reporting of which project fields are configured vs unconfigured (one-line summary, opt-in based on `github.project` presence)
- [x] 5.4 Add `lib/tests/test_gh_project.sh` covering: configured field sets correctly, unconfigured field skips silently, partial config (status only) behaves correctly

## 6. release.block_on_labels and release.dry_run_default

- [x] 6.1 Implement pre-flight label-block check in `commands/ship/release.md`: query `gh issue list --label <name> --state open --json number,title` for each entry in `release.block_on_labels`
- [x] 6.2 On any non-empty result, abort with a message citing the labels and the first matching issue numbers
- [x] 6.3 Implement `release.dry_run_default` handling: when true and `--apply` not passed, simulate every release step without mutation
- [x] 6.4 Document `--apply` flag in `commands/ship/release.md` frontmatter and prompt
- [x] 6.5 Add tests for both behaviors (label-blocked release aborts; dry-run-default with and without `--apply`)

## 7. Documentation

- [x] 7.1 Extend `docs/extension-model.md` § Configuration schema with the `paths.*` and `worktree.*` formalized blocks (types, defaults, examples)
- [x] 7.2 Extend `docs/extension-model.md` with a dedicated `area_to_repo` section enumerating all five edge cases with worked examples
- [x] 7.3 Extend `docs/extension-model.md` § release with `release.repos` (multi-repo example), `release.block_on_labels`, `release.dry_run_default`
- [x] 7.4 Extend `docs/extension-model.md` with `github.project_fields` and a `gh project field-list --format json` derivation example
- [x] 7.5 Extend `templates/extension/config.yaml` with commented examples for every formalized key (paths, worktree, area_to_repo with each edge case, release multi-repo, project_fields)
- [x] 7.6 Verify templates remain universal: no client/product names

## 8. Verification

- [x] 8.1 Run `openspec validate config-driven-paths-and-gates --strict` and resolve any issues
- [x] 8.2 Run all `lib/tests/test_*.sh` — all pass, including the new path/area/project tests
- [ ] 8.3 Smoke-test in this drydock repo: set `paths.requirements: docs/req`; run `/dd:req:vision`; verify output lands in the override path; revert *(deferred — interactive)*
- [ ] 8.4 Smoke-test multi-repo: declare `release.repos` with two entries (one being this repo, one being a temp throwaway sibling repo); dry-run `/dd:ship:release`; verify topological order in output *(deferred — needs throwaway sibling repo)*
- [ ] 8.5 Smoke-test area routing: declare `area_to_repo: {docs: .}`; promote a `Area: docs` issue; verify it stays in current repo *(deferred — interactive)*
- [x] 8.6 Final audit grep: zero hardcoded path/branch/routing literals in `commands/` outside markdown blocks
