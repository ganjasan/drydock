---
description: Cut a release for the current repo — bump version, generate changelog, tag, optionally coordinate with downstream repos
argument-hint: "<bump: major|minor|patch> [--dry-run]"
allowed-tools: Bash, Read, Write, Edit, SlashCommand
---

Run a release pipeline for the current repo. Load merged Drydock config (`source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load`) and the hook dispatcher (`source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"`). Single-repo by default; if `cfg_array_get release.repos | wc -l` is ≥ 2, the `release-coordinator` agent is invoked to sequence cross-repo effects.

Argument: `$ARGUMENTS`:
- `<bump>` — `major`, `minor`, or `patch`
- optional `--apply` — perform mutating operations. Without `--apply`, runs in dry-run mode if `cfg_get release.dry_run_default` is `true`; otherwise the absence of `--apply` defaults to applying.

## Procedure

### 1. Resolve inputs

- `bump` from `$ARGUMENTS[0]`.
- `--apply` flag handling: if `cfg_get release.dry_run_default` is `true` and `--apply` is not passed, set internal `DRY_RUN=1`. Print "DRY-RUN mode" at the top of the report and skip all mutating operations (commits, tags, pushes, releases).

### 2. Pre-release lifecycle hook

Build payload with `bump`, current branch, current version (read from manifest):

```bash
extra=$(jq -cn --arg bump "$bump" --arg version "$current_version" '{bump: $bump, current_version: $version}')
dd_hook_invoke pre-release "$extra" || exit $?
```

If `<repo>/.drydock/hooks/pre-release.sh` exists and is executable, it runs with the payload on stdin. Non-zero exit aborts the entire release before any other work.

### 3. Block-on-labels pre-flight

For each label in `cfg_array_get release.block_on_labels`:
```bash
gh issue list --label "$label" --state open --json number,title --jq '.[] | "\(.number) \(.title)"'
```
If any returns non-empty, abort the release citing the label and the first matching issue numbers. (Defaults to no-op when `release.block_on_labels` is unset.)

### 4. Enforce universal gates

For the **current** repo, before any side effects:

a. **CI green on `main`**: `gh run list --branch main --limit 5 --json status,conclusion` — latest commit's checks must all pass.
b. **Working tree clean** on `main` — no uncommitted changes.

If any check fails, refuse to proceed (even in dry-run, mark it as red in the report).

### 5. Run configured release gates

Read `cfg_array_get release.gates` — a list of slash-command references (e.g. `/dd:build:test`, `/conformance`, `/parity`). For each entry in declared order:

- Resolve the command via Claude Code's native slash-command dispatch (built-in `/dd:*` and project-local `<repo>/.claude/commands/*` both work).
- If the referenced command does not resolve → abort with `command not found: <name>`.
- Invoke the command and check exit code.
- On non-zero exit → abort the release citing which gate failed; do not run subsequent gates.

If `release.gates` is unset or empty: skip this step entirely.

### 6. Compute next version

Read current version, in priority order, from:
- Latest git tag matching `v*` (e.g. `v1.2.3`).
- `pyproject.toml [project] version`, `package.json "version"`, `Cargo.toml [package] version`, `go.mod` (no field, infer from latest tag), `setup.py version=`.
- A `version` key in `plugin.json` (Claude Code plugins).

Apply bump:
- `major`: `1.2.3` → `2.0.0`
- `minor`: `1.2.3` → `1.3.0`
- `patch`: `1.2.3` → `1.2.4`

### 7. Generate changelog

From `git log --oneline <last-tag>..HEAD`, group commits by conventional-commit prefix (feat / fix / docs / chore / refactor / test). Write or prepend to `CHANGELOG.md`:

```markdown
## v<new-version> — <YYYY-MM-DD>

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

### 8. Bump version in manifest(s)

Edit every file holding the version string — search for the previous version literal and replace, ensuring no stray matches in unrelated files.

### 9. Commit, tag, push

```
git commit -am "release: v<new-version>"
git tag -a v<new-version> -m "Release v<new-version>"
git push origin main
git push origin v<new-version>
```

### 10. GitHub Release

```
gh release create v<new-version> \
  --title "v<new-version>" \
  --notes-file <changelog-excerpt-file>
```

### 11. Multi-repo coordination (only if configured)

If `cfg_array_get release.repos` returns two or more entries (each with `depends_on:` relationships), spawn the `release-coordinator` agent. The agent computes order, propagates pins downstream, and prepares a cross-repo announcement.

If only the current repo is in scope, **do not** invoke the coordinator.

### 12. Optional artifact build (project-specific)

Drydock does not build container images or publish packages by default. If the project requires it:
- A repo-local `release.sh` / `Makefile` / `package.json` script handles publishing.
- The release command can shell out to `scripts/release-publish.sh` if it exists; the script itself owns the build/push.

### 13. Report

```
Released <repo> v<new-version>
├ Gates:     ✓ CI green, no blocking bugs, clean tree
├ Tag:       v<new-version> pushed
├ Release:   <URL>
├ Changelog: <N> added, <N> fixed, <N> changed
└ Downstream: <coordinator report or "—">
```

## Guardrails

- When `release.dry_run_default: true`, dry-run is the default; `--apply` is required to mutate state.
- Never force-push a tag that already exists.
- Never bypass gates — failing gates means a code change, not a flag toggle. Both the `pre-release` lifecycle hook and `release.gates` entries are user authority to refuse the release.
- Never invoke `release-coordinator` for a single-repo project (`release.repos` ≤ 1).
- Never publish build artifacts from a dirty tree.
