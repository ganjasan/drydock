# agents/

Claude Code subagents invoked by Drydock commands. Each agent is a single Markdown file with YAML frontmatter (`name`, `description`, `tools`) followed by the agent's system prompt.

## Shipped agents

| Agent | One-liner |
|-------|-----------|
| `code-reviewer`        | Reviews diffs against the active OpenSpec change's tasks and specs (Drydock-flavored — distinct from Claude Code's built-in code-reviewer in that findings are anchored to OpenSpec artifacts) |
| `code-explorer`        | Maps execution paths AND surfaces traceability links (ADRs, use cases, vision sections, active changes) — distinct from the built-in code-explorer which traces code only |
| `code-architect`       | Produces feature designs shaped exactly as an OpenSpec `design.md` section (drop-in compatible with `/dd:build:design`) |
| `traces-linter`        | Verifies bidirectional `traces_to` frontmatter references; reports orphans, broken links, and one-way links. Read-only |
| `release-coordinator`  | Sequences multi-repo releases when `config.yaml` declares dependent repos. Not invoked for single-repo projects |

## Not in Drydock

`raw-classifier` is **not** shipped in Drydock. It classifies inbound client/meeting/email content into a predefined inbox layout that is highly specific to one project's hub structure. It remains in the upstream APZ plugin and any other project-specific layer that needs it.

## Tool allowlists

Every agent declares its `tools:` allowlist explicitly. Read-only agents (`traces-linter`, `code-reviewer`, `code-explorer`, `code-architect`) do not list `Write` or `Edit`. No agent uses an unbounded wildcard.

## Invocation

Drydock commands invoke these agents via the Agent tool, passing the appropriate `subagent_type`. Agents may also be invoked directly by the user when working autonomously.

See [../docs/skills-catalog.md](../docs/skills-catalog.md) for cross-references between agents, skills, and commands.
