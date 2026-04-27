---
description: Cut a release for the current repo — bump version, generate changelog, tag, optionally coordinate with downstream repos
argument-hint: "<bump: major|minor|patch> [--dry-run]"
allowed-tools: Bash, Read, Write, Edit, SlashCommand
---

Run a release pipeline for the current repo. Single-repo by default; if `config.yaml` declares multiple repositories with `depends_on` ordering, the `release-coordinator` agent is invoked to sequence cross-repo effects.

Argument: `$ARGUMENTS`:
- `<bump>` — `major`, `minor`, or `patch`
- optional `--dry-run` — run all checks and print the plan, take no side effects

## Procedure

### 1. Resolve inputs

- `bump` from `$ARGUMENTS[0]`.
- `--dry-run` flag — strongly recommended for the first run. Treat as default-on if `release.dry_run_default: true` is in `config.yaml`.

### 2. Enforce gates

For the **current** repo, before any side effects:

a. **CI green on `main`**: `gh run list --branch main --limit 5 --json status,conclusion` — latest commit's checks must all pass.
b. **No open critical bugs**: `gh issue list --label "<bug-label>" --state open` for the configured bug label (default `bug`). Threshold for blocking is project-specific; `config.yaml` may declare `release.block_on_labels: [priority/P0, priority/P1]`.
c. **Working tree clean** on `main` — no uncommitted changes.

If any check fails, refuse to proceed (even in dry-run, mark it as red in the report).

Project-specific gates (e.g. conformance, parity) are **not** part of Drydock's release command — they belong in plugin-layer extensions or in the project's CI pipeline.

### 3. Compute next version

Read current version, in priority order, from:
- Latest git tag matching `v*` (e.g. `v1.2.3`).
- `pyproject.toml [project] version`, `package.json "version"`, `Cargo.toml [package] version`, `go.mod` (no field, infer from latest tag), `setup.py version=`.
- A `version` key in `plugin.json` (Claude Code plugins).

Apply bump:
- `major`: `1.2.3` → `2.0.0`
- `minor`: `1.2.3` → `1.3.0`
- `patch`: `1.2.3` → `1.2.4`

### 4. Generate changelog

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

### 5. Bump version in manifest(s)

Edit every file holding the version string — search for the previous version literal and replace, ensuring no stray matches in unrelated files.

### 6. Commit, tag, push

```
git commit -am "release: v<new-version>"
git tag -a v<new-version> -m "Release v<new-version>"
git push origin main
git push origin v<new-version>
```

### 7. GitHub Release

```
gh release create v<new-version> \
  --title "v<new-version>" \
  --notes-file <changelog-excerpt-file>
```

### 8. Multi-repo coordination (only if configured)

If `config.yaml` declares two or more repos under `release.repos:` with `depends_on:` relationships, spawn the `release-coordinator` agent. The agent computes order, propagates pins downstream, and prepares a cross-repo announcement.

If only the current repo is in scope, **do not** invoke the coordinator.

### 9. Optional artifact build (project-specific)

Drydock does not build container images or publish packages by default. If the project requires it:
- A repo-local `release.sh` / `Makefile` / `package.json` script handles publishing.
- The release command can shell out to `scripts/release-publish.sh` if it exists; the script itself owns the build/push.

### 10. Report

```
Released <repo> v<new-version>
├ Gates:     ✓ CI green, no blocking bugs, clean tree
├ Tag:       v<new-version> pushed
├ Release:   <URL>
├ Changelog: <N> added, <N> fixed, <N> changed
└ Downstream: <coordinator report or "—">
```

## Guardrails

- `--dry-run` is the recommended first invocation. No side effects in dry-run mode.
- Never force-push a tag that already exists.
- Never bypass gates — failing gates means a code change, not a flag toggle.
- Never invoke `release-coordinator` for a single-repo project.
- Never publish build artifacts from a dirty tree.
