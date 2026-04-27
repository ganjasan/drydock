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
- **`raw.*`** — Per-source ingestion config consumed by `/dd:raw:ingest-*` commands. See § "Raw phase configuration" below for the full schema.

### paths.* and worktree.*

| Key | Type | Default |
|---|---|---|
| `paths.requirements` | string | `requirements` |
| `paths.requirements_subdirs.vision` | string | `vision` |
| `paths.requirements_subdirs.stakeholders` | string | `stakeholders` |
| `paths.requirements_subdirs.use_cases` | string | `use-cases` |
| `paths.requirements_subdirs.adr` | string | `adr` |
| `paths.openspec.changes` | string | `openspec/changes` |
| `paths.openspec.specs` | string | `openspec/specs` |
| `paths.raw_root` | string | `raw` |
| `paths.raw_subdirs.{incoming,meetings,feedback,ideas,competitors,client_boards}` | string | `_incoming`, `meetings`, `feedback`, `ideas`, `competitors`, `client-boards` |
| `worktree.enabled` | bool | `false` |
| `worktree.base_dir` | string (absolute or relative-to-repo) | `.worktrees` |
| `worktree.naming` | template (tokens: `<issue-id>`, `<slug>`) | `wt-<issue-id>` |
| `worktree.branch_naming` | template (tokens: `<issue-id>`, `<slug>`) | `feature/<issue-id>-<slug>` |

Templates accept exactly two tokens: `<issue-id>` and `<slug>`. Unknown tokens produce an error from `dd_branch_name` / `dd_worktree_dir` (additional tokens require a documented schema bump).

### area_to_repo (five edge cases)

`area_to_repo` is a map from issue-Area string to target repo path. Resolution via `dd_resolve_area`:

| # | Condition | Behavior | Example |
|---|---|---|---|
| 1 | `area_to_repo` unset entirely | Current repo | (no entry) → `<repo>` |
| 2 | Set, area not in map | Fail loud with copy-pasteable mapping snippet | `area_to_repo: {a: b}`, asking `c` → error |
| 3 | Value is `.` | Current repo | `docs: .` → `<repo>` |
| 4 | Absolute path | Used verbatim | `shared: /opt/shared-repo` → `/opt/shared-repo` |
| 5 | Relative path (sibling-name pattern) | `<parent-of-current-repo>/<value>` | `frontend: my-frontend` from `/me/work/hub` → `/me/work/my-frontend` |

The sibling-name pattern (entry 5) is the typical multi-repo workspace shape: hub plus siblings.

### release.* full schema

| Key | Type | Default | Purpose |
|---|---|---|---|
| `release.gates` | list of slash-command references | `[]` | Sequenced commands run before tag; any non-zero aborts |
| `release.block_on_labels` | list of strings | `[]` | Open issues with any listed label abort the release |
| `release.dry_run_default` | bool | `false` | When true, `/dd:ship:release` requires `--apply` to mutate |
| `release.repos` | list of `{name, path, depends_on[]}` | `[]` | Multi-repo coordination — ≥ 2 entries triggers the agent |

**Multi-repo example:**

```yaml
release:
  repos:
    - name: protocol
      path: ../protocol           # sibling repo
      depends_on: []
    - name: sdk
      path: ../sdk
      depends_on: [protocol]
    - name: platform
      path: ../platform
      depends_on: [protocol, sdk]
```

Topological order via Kahn's algorithm with alphabetical tie-break: `[protocol, sdk, platform]`. Cycles abort the entire release before any side effect.

### github.project_fields (opt-in field setting)

Plan commands set GitHub Projects v2 field values via `dd_project_field_set`. Each field is opt-in: declare `github.project_fields.<name>.id` and `.options.<key>` to enable; absent → silent no-op. Currently supported: `status`, `priority`, `phase`, `area`.

Derive field IDs and option IDs once per project:

```bash
gh project field-list <project-number> --owner <org> --format json \
  | jq '.fields[] | {id, name, options: ([.options[]? | {id, name}])}'
```

Drop the resulting IDs into `github.project_fields.*` in your `<repo>/.drydock/config.yaml`.

### Reading config from a command

Commands source the loaders and read via helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh";       dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/paths.sh"          # dd_path / dd_branch_name / dd_worktree_dir
source "${CLAUDE_PLUGIN_ROOT}/lib/area_routing.sh"   # dd_resolve_area
source "${CLAUDE_PLUGIN_ROOT}/lib/gh_project.sh"     # dd_project_field_set

triage_label="$(cfg_get github.triage_label)"        # scalar
gates="$(cfg_array_get release.gates)"               # newline-separated list
areas="$(cfg_keys_of area_to_repo)"                  # newline-separated keys
if cfg_has github.project.id; then ... fi            # presence check

req_dir="$(dd_path requirements_subdir vision)"      # absolute path
branch="$(dd_branch_name 42 dark-mode)"              # token-substituted name
target="$(dd_resolve_area frontend)"                 # routing
dd_project_field_set "$item" status ready             # opt-in field set
```

Direct reads of `${CLAUDE_PLUGIN_ROOT}/config.yaml` from command files are forbidden; the merged loader is the only supported access path.

### Alternate locations are rejected

Drydock searches **only** at `<repo>/.drydock/config.yaml`. Configuration files at `<repo>/drydock.yaml` or `<repo>/.drydock.yaml` cause the loader to abort with a "non-supported location" error rather than silently ignoring them — this prevents users from relying on a path Drydock will never read.

## Raw phase configuration

The `/dd:raw:*` commands read every source-specific filter, ID, and window from `raw.*` config keys. Universal defaults; per-repo values plug in via `<repo>/.drydock/config.yaml`.

### Source filters

| Source | Keys | Semantics |
|---|---|---|
| `gmail` | `query` (string), `labels_to_track` (list), `since_days` (int, default 7) | Combined into Gmail's search syntax: `query AND label:<each> AND newer_than:<since_days>d` |
| `calendar` | `calendar_ids` (list), `look_back_days` (int, default 7), `look_ahead_days` (int, default 14) | Time window for event ingestion |
| `drive` | `folder_ids` (list), `file_types` (list of mime types), `since_days` (int, default 7) | Files matching mime types modified in window |
| `notion` | `databases` (list of `{id, label}`) | Per-database watermarked pulls |
| `linear` | `teams` (list), `filter` (Linear filter expression) | Issues + comments updated since per-team watermark |
| `github` | `repos` (list of `<owner>/<repo>`), `since_days` (int, default 7) | Issues + comments from external repos (the current repo is never targeted) |

### Transcription

| Key | Type | Purpose |
|---|---|---|
| `raw.transcribe.provider` | string | e.g. `openai-whisper`, `google-stt`, `deepgram` |
| `raw.transcribe.model` | string | provider-specific model identifier |

`/dd:raw:transcribe` aborts when `provider` is unset.

### Classifier categories

| Key | Type | Default |
|---|---|---|
| `raw.classifier.categories` | list of `{name, description}` | `[meetings, feedback, ideas, competitors, client-boards]` with documented descriptions |

Custom category sets are honored. The classifier requires at least two categories; fewer triggers a refusal.

### Frontmatter schema for raw entries

Every file written into the raw inbox by `/dd:raw:capture` or `/dd:raw:ingest-*` carries this frontmatter (required keys must be present):

```yaml
---
source: <gmail | calendar | drive | notion | linear | github | manual>
captured_at: <ISO 8601 UTC datetime when Drydock filed the item>
dedup_key: <deterministic per-item identifier — stable across re-runs>
# optional:
captured_by: claude-code:/dd:raw:<command-name>
original_at: <ISO 8601 — when the source itself recorded, e.g. email send time>
parties: [<emails or names mentioned>]
links: [<URLs referenced>]
attachments: [<file references — paths or "drive:<file-id>">]
topics: [<short lowercase tags>]
proposed_category: <category-name or empty>
traces_to:
  use_cases: [<UC-NNN ids>]
  adrs: [<NNNN-slug>]
  issues: [<owner/repo#num>]
  raw: [<paths to other raw entries>]
# source-specific blocks (optional, depending on `source`):
gmail:    { thread_id, labels: [...] }
calendar: { calendar_id, start, end, location, recurrence }
drive:    { file_id, mime_type, size_bytes, is_recording }
notion:   { page_id, database_id, database_label, properties: {...} }
linear:   { team, identifier, status, priority, assignee }
github:   { repo, number, state, author }
transcribe: { provider, model, transcribed_at }
---
```

### Per-source `dedup_key` schemes

| Source | `dedup_key` |
|---|---|
| `manual` | `manual:<sha256-of-body>` |
| `gmail` | `gmail:<message-id>` |
| `calendar` | `calendar:<event-id>` |
| `drive` | `drive:<file-id>` |
| `notion` | `notion:<page-id>` |
| `linear` | `linear:<identifier>` (e.g. `linear:ENG-123`) |
| `github` | `github:<owner>/<repo>#<num>` |

Collisions are merged, not duplicated — `/dd:raw:process` unions frontmatter and concatenates bodies under a `--- duplicate captured at <captured_at> ---` separator.

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
