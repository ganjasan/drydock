# commands/

Claude Code slash commands, grouped by workflow phase:

- `req/` — requirements (`/sw:req:*`)
- `build/` — build loop (`/sw:build:*`)
- `ship/` — release pipeline (`/sw:ship:*`)
- `plan/` — planning and backlog (`/sw:plan:*`)

Each file is a Markdown document with YAML frontmatter (`description`, `allowed-tools`) and the command prompt body.

Ports from APZ will land here during v0.1.
