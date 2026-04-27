# Extension Model

How a project plugs its own specifics into Drydock without forking the plugin or maintaining a sibling plugin. Three mechanisms, all repo-local:

| Mechanism | Where | Purpose |
|---|---|---|
| **Configuration** | `<repo>/.drydock/config.yaml` | Declarative — paths, sources, gates, routing |
| **Lifecycle hooks** | `<repo>/.drydock/hooks/<event>.sh` | Imperative — shell scripts at workflow boundaries |
| **Project-local commands** | `<repo>/.claude/commands/<name>.md` | Custom slash commands referenced from config |

The Drydock plugin code is universal. Project-specific values (Gmail filters, conformance test runners, content-leak guards, area-to-repo maps) live in the consuming repo, in version control, next to the code they affect. See [ADR-0004](../requirements/adr/0004-universal-workflow-and-project-extensions.md) for the architectural rationale.

## Configuration

### Three-layer merge

Drydock loads configuration from three layers, with later layers overriding earlier ones at the **leaf-key** level:

| Order | Path | Purpose |
|---|---|---|
| 1 | `${CLAUDE_PLUGIN_ROOT}/config.yaml` | Plugin defaults shipped with Drydock |
| 2 | `~/.drydock/config.yaml` | Personal cross-repo overrides (optional) |
| 3 | `<repo>/.drydock/config.yaml` | Per-repo, checked-in — **wins** |

Merge semantics:

- **Maps merge key-by-key.** If layer 1 has `area_to_repo: {a: x, b: y}` and layer 3 has `area_to_repo: {b: z, c: w}`, the effective value is `{a: x, b: z, c: w}`.
- **Lists replace wholesale.** If layer 1 has `release.gates: [/dd:build:test]` and layer 3 has `release.gates: [/conformance]`, the effective value is exactly `[/conformance]`.
- **Missing layers are ignored.** Any of the three files may be absent; the merge proceeds with whatever is present.

The merged result is materialized to a per-invocation JSON tempfile pointed at by `$DRYDOCK_CONFIG_PATH`. Hook scripts receive the same path in their stdin payload under `config_path`. The tempfile is cleaned up automatically on command completion.

### Worked example

```
${CLAUDE_PLUGIN_ROOT}/config.yaml          # layer 1
  worktree:
    enabled: false

~/.drydock/config.yaml                     # layer 2
  worktree:
    enabled: true                          # this developer always wants worktrees

<my-repo>/.drydock/config.yaml             # layer 3
  worktree:
    enabled: false                         # except in this specific repo
  paths:
    requirements: docs/req
```

Effective merged config:

```yaml
worktree:
  enabled: false       # layer 3 wins
paths:
  requirements: docs/req
```

### Schema

The full schema and built-in defaults are listed in [`templates/extension/config.yaml`](../templates/extension/config.yaml) (commented). Top-level blocks:

- **`paths.*`** — Filesystem paths under the repo root: `paths.requirements`, `paths.requirements_subdirs.{vision,stakeholders,use_cases,adr}`, `paths.openspec.{changes,specs}`, `paths.raw_root`, `paths.raw_subdirs.*`.
- **`github.*`** — GitHub Project number/ID/name, `github.project_fields.{status,priority,phase,area}` field IDs and option maps, `github.triage_label`, `github.triage_repos`.
- **`worktree.*`** — `worktree.enabled`, `worktree.base_dir`, `worktree.naming`, `worktree.branch_naming`. Tokens supported in naming templates: `<issue-id>`, `<slug>`.
- **`area_to_repo`** — Map from issue-Area value to target repo path. Edge cases: `.` for current repo, absolute paths, relative paths (resolved against parent of current repo). When `area_to_repo` is set but the requested area is not in the map, `/dd:plan:promote` aborts with a fail-loud message.
- **`release.*`** — `release.gates` (slash-command references), `release.repos` (multi-repo coordination with `depends_on`), `release.block_on_labels`, `release.dry_run_default`.
- **`raw.*`** — Per-source ingestion config: `raw.gmail.*`, `raw.calendar.*`, `raw.drive.*`, `raw.notion.*`, `raw.linear.*`, `raw.github.*`, `raw.transcribe.*`, `raw.classifier.*`. Populated by the [`add-raw-phase`](../openspec/changes/add-raw-phase/) change; see also the schema reference in that change's spec.

### Reading config from a command

Commands source the loader and read keys via helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
dd_config_load                                  # idempotent; materializes the merged config

triage_label="$(cfg_get github.triage_label)"   # scalar
gates="$(cfg_array_get release.gates)"          # newline-separated list
areas="$(cfg_keys_of area_to_repo)"             # newline-separated keys
if cfg_has github.project.id; then ... fi       # presence check
```

Direct reads of `${CLAUDE_PLUGIN_ROOT}/config.yaml` from command files are forbidden; the merged loader is the only supported access path.

### Alternate locations are rejected

Drydock searches **only** at `<repo>/.drydock/config.yaml`. Configuration files at `<repo>/drydock.yaml` or `<repo>/.drydock.yaml` cause the loader to abort with a "non-supported location" error rather than silently ignoring them — this prevents users from relying on a path Drydock will never read.

## Lifecycle hooks

### Discovery and protocol

Hooks are shell scripts at `<repo>/.drydock/hooks/<event>.sh`. Discovery is by file presence:

- **Missing file** → silently skipped.
- **Present but not executable** → one-line warning, skipped.
- **Present and executable** → invoked.

Each hook receives a JSON payload on standard input. The payload is built per-event but always contains:

```json
{
  "event":       "<hook-name>",
  "repo_path":   "/abs/path/to/repo",
  "config_path": "/tmp/.../merged-config.json"
}
```

…plus event-specific fields. The hook can re-read the merged config from `config_path` if it needs to inspect any setting.

### Exit-code semantics

| Category | Behavior on non-zero exit |
|---|---|
| `pre-*` | **Aborts** the originating Drydock operation. The hook is the user's authority to refuse. |
| `post-*` | **Warning only** — the operation has already happened; rolling back is out of scope. |
| `session-start` | Warning only — Claude Code session continues. |

### Initial hook set (v0.2)

| Event | Trigger | Payload extras (beyond `event`/`repo_path`/`config_path`) | Aborts on non-zero? |
|---|---|---|---|
| `pre-pr` | `/dd:ship:pr` before opening the PR | `branch`, `commits[]` | yes |
| `pre-release` | `/dd:ship:release` before any gate or tag | `bump`, `current_version` | yes |
| `post-archive` | `/dd:ship:archive` after delta sync + archive | `change_slug` | no (warning only) |
| `post-capture` | `/dd:raw:capture` and `/dd:raw:ingest-*`, **per item filed** | `item_path`, `source` | no (warning only) |
| `session-start` | Claude Code SessionStart event (startup, clear, compact) | (none) | no (warning only) |

The names are stable within v0.x; new hook points may be added but existing names will not be renamed or removed without a major version bump.

### Worked example

A repo wants to refuse PRs that include literal "TODO" lines in the diff:

```bash
# <repo>/.drydock/hooks/pre-pr.sh
#!/usr/bin/env bash
set -euo pipefail

payload="$(cat)"
branch="$(jq -r '.branch'           <<<"$payload")"
commits="$(jq -r '.commits[]?'      <<<"$payload")"
repo_path="$(jq -r '.repo_path'     <<<"$payload")"

cd "$repo_path"
violations=$(
  for sha in $commits; do
    git show --unified=0 --format= "$sha" \
      | awk '/^\+[^+]/ && /\bTODO\b/ { print "  - " $0 }'
  done
)

if [ -n "$violations" ]; then
  echo "pre-pr: branch '$branch' adds TODO markers — refusing PR" >&2
  echo "$violations" >&2
  exit 1
fi
```

Drop this in `<repo>/.drydock/hooks/pre-pr.sh`, `chmod +x`, and `/dd:ship:pr` will refuse to open a PR whose diff contains `TODO`.

See [`templates/extension/hooks/`](../templates/extension/hooks/) for example scripts covering all five initial events.

## Project-local commands and command-references

### The contract

Configuration values that accept slash-command references (e.g. `release.gates`) hold **slash-command names** that Drydock invokes via Claude Code's standard slash-command dispatch. Both forms are addressable:

- **Built-in `/dd:*`** — commands shipped by the Drydock plugin (e.g. `/dd:build:test`).
- **Project-local `<repo>/.claude/commands/<name>.md`** — Claude Code's native per-project command directory. Invoked as `/<name>`.

Example `release.gates`:

```yaml
release:
  gates:
    - /dd:build:test           # built-in: runs the repo's test suite
    - /conformance             # project-local: <repo>/.claude/commands/conformance.md
    - /parity                  # project-local: <repo>/.claude/commands/parity.md
```

Drydock does not re-implement command discovery — it relies on Claude Code's native mechanism. If a referenced command does not resolve, the invoking operation aborts with a clear `command not found: <name>` error rather than skipping silently.

### When to use which mechanism

| Need | Use |
|---|---|
| Set a value that a Drydock command reads | `<repo>/.drydock/config.yaml` |
| Fire a script at a specific workflow boundary | `<repo>/.drydock/hooks/<event>.sh` |
| Make a slash-command for project-specific logic | `<repo>/.claude/commands/<name>.md`, reference from config |

The three layers are deliberate:

- **Config** is declarative and reviewable.
- **Hooks** are imperative, scoped to one event each, with well-defined input/output.
- **Project-local commands** are first-class slash commands, discoverable in any session, reusable from gates and from the user's prompt.

## End-to-end example

A repo `apilize-protocol` wants:

1. Three release gates: tests, Apilize Protocol conformance, model parity.
2. A `pre-release` hook that refuses release if `CHANGELOG.md` is unchanged since the last tag.
3. The `/conformance` and `/parity` commands implementing the actual test runners.

Layout:

```
apilize-protocol/
├── .drydock/
│   ├── config.yaml
│   └── hooks/
│       └── pre-release.sh
└── .claude/
    └── commands/
        ├── conformance.md
        └── parity.md
```

`apilize-protocol/.drydock/config.yaml`:

```yaml
release:
  gates:
    - /dd:build:test
    - /conformance
    - /parity
```

`apilize-protocol/.drydock/hooks/pre-release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
payload="$(cat)"
repo_path="$(jq -r '.repo_path' <<<"$payload")"
last_tag="$(git -C "$repo_path" describe --abbrev=0 --tags 2>/dev/null || true)"
if [ -n "$last_tag" ]; then
  changed=$(git -C "$repo_path" diff --name-only "${last_tag}..HEAD" -- CHANGELOG.md)
  [ -n "$changed" ] || { echo "CHANGELOG.md unchanged since $last_tag" >&2; exit 1; }
fi
```

`apilize-protocol/.claude/commands/conformance.md`:

```markdown
---
description: Run Apilize Protocol conformance tests against the local container.
allowed-tools: Bash
---

cd "${CLAUDE_PROJECT_DIR}"
docker compose run --rm conformance-runner pytest tests/conformance/ -v
```

When the user runs `/dd:ship:release minor`:

1. Drydock loads merged config; sees `release.gates` populated.
2. Invokes `pre-release.sh` — refuses if `CHANGELOG.md` is stale.
3. Runs universal preflight (CI green, working tree clean, no blocking labels).
4. Dispatches `/dd:build:test`, `/conformance`, `/parity` in order via Claude Code's slash mechanism. Any non-zero exit aborts.
5. On all gates passing, bumps version, writes changelog, tags, pushes.

The Drydock plugin code knows nothing about Apilize Protocol. The whole workflow is composed from generic primitives + repo-local config and commands.

## See also

- [`templates/extension/`](../templates/extension/) — copy-paste skeleton for a new repo.
- [methodology.md](methodology.md) § "Project-specific extensions".
- [workflow.md](workflow.md) — where each hook fires in the end-to-end loop.
- [ADR-0004](../requirements/adr/0004-universal-workflow-and-project-extensions.md) — architectural decision behind this model.
