# commands/

Claude Code slash commands, grouped by workflow phase:

- `req/` — requirements (`/dd:req:*`)
- `build/` — build loop (`/dd:build:*`)
- `ship/` — release pipeline (`/dd:ship:*`)
- `plan/` — planning and backlog (`/dd:plan:*`)

Each file is a Markdown document with YAML frontmatter (`description`, `allowed-tools`) and the command prompt body.

Ports from APZ will land here during v0.1.
