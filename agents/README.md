# agents/

Claude Code sub-agents invoked by Shipwright commands. Each agent is a Markdown file with a YAML frontmatter block (`name`, `description`, `tools`) and a system prompt body.

Planned agents (ported from APZ during v0.1):

- `code-reviewer` — reviews diffs for bugs, security, conventions.
- `code-explorer` — traces execution paths and architecture.
- `code-architect` — designs feature architectures.
- `traces-linter` — verifies bidirectional `traces_to` frontmatter.
- `release-coordinator` — orchestrates multi-repo releases.
- `raw-classifier` — classifies raw signal artifacts (stays in APZ — domain-specific).

See [../docs/skills-catalog.md](../docs/skills-catalog.md) for the full catalog.
