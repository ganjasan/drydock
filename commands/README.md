# commands/

Claude Code slash commands shipped by Drydock, grouped by workflow phase.

Each file is a Markdown document with YAML frontmatter (`description`, `argument-hint`, `allowed-tools`) and a command prompt body. Commands are auto-discovered via `plugin.json`.

## Top-level

| Command | One-liner |
|---------|-----------|
| `/dd:status` | Show current position — repo, branch, worktree, active OpenSpec change, open PRs, optional project board snapshot |
| `/dd:next`   | Suggest exactly one next concrete action based on observed workflow state |

## req/ — Requirements (`/dd:req:*`)

| Command | One-liner |
|---------|-----------|
| `/dd:req:vision`      | Create or update a Vision and Scope document (Wiegers form) |
| `/dd:req:use-case`    | Write a Wiegers/Cockburn use case with auto-numbering |
| `/dd:req:stakeholder` | Create a stakeholder profile with category placement |
| `/dd:req:adr`         | Create an Architectural Decision Record with auto-numbering and traceability |
| `/dd:req:review`      | Run a Wiegers requirements review (eight-criteria report) on a file or folder |
| `/dd:req:elicit`      | Prepare a requirements elicitation plan (gaps, techniques, schedule) |

## build/ — Build loop (`/dd:build:*`)

| Command | One-liner |
|---------|-----------|
| `/dd:build:start`   | Start work on an issue — branch, optional worktree, OpenSpec change skeleton |
| `/dd:build:explore` | Q&A mode for ambiguous scope — wraps `/opsx:explore` |
| `/dd:build:design`  | Generate proposal/design/tasks via `/opsx:ff` or `/opsx:continue` |
| `/dd:build:code`    | Resume implementation — pick up next unchecked task and ship it |
| `/dd:build:test`    | Run the repo's test suite per its declared conventions |
| `/dd:build:ff`      | Fast-forward — generate all OpenSpec artifacts in one pass |
| `/dd:build:verify`  | Verify a change's internal coherence before archive |

## ship/ — Release pipeline (`/dd:ship:*`)

| Command | One-liner |
|---------|-----------|
| `/dd:ship:pr`      | Open a draft PR linked to the active OpenSpec change and originating issue |
| `/dd:ship:archive` | After merge: verify, sync deltas → specs, archive the change |
| `/dd:ship:release` | Cut a release — gates, version bump, changelog, tag; multi-repo coordination is opt-in |

> **Not in Drydock**: `/dd:ship:conformance` and `/dd:ship:parity` are project-specific test gates (e.g. Apilize Protocol). They stay in plugins that layer on top of Drydock.

## plan/ — Backlog and triage (`/dd:plan:*`)

| Command | One-liner |
|---------|-----------|
| `/dd:plan:add`     | Capture a new backlog item — creates a GitHub issue with sensible defaults |
| `/dd:plan:triage`  | Walk through `status/needs-triage` issues and fill missing fields interactively |
| `/dd:plan:promote` | Promote a triaged issue to an OpenSpec change (optional area→repo routing) |

## Conventions

- Command files are kebab-case under `commands/<phase>/<action>.md`.
- Top-level commands (`status`, `next`) live at `commands/<name>.md`.
- Every command body ends with a Guardrails section listing what the command MUST NOT do.
- Commands resolve configuration via the merged loader in `lib/config.sh` (`source` it then call `cfg_get`/`cfg_has`/`cfg_array_get`/`cfg_keys_of`). The loader merges three layers (later wins): plugin-root → `~/.drydock/config.yaml` → `<repo>/.drydock/config.yaml`. Built-in defaults apply when no layer declares a key. See `docs/extension-model.md`.
