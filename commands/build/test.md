---
description: Run the test suite for the current repo per its declared conventions
allowed-tools: Bash, Read, Grep
---

Run tests. The repo's `CLAUDE.md` (or `AGENTS.md`, or `README.md`) is the source of truth for which command to run and which conventions to enforce. **Drydock does not assume any specific test framework.**

## Procedure

### 1. Discover test conventions

Read, in order:
- `<repo-root>/CLAUDE.md` (highest priority — Drydock's expected location for project rules)
- `<repo-root>/AGENTS.md`
- `<repo-root>/README.md`

Look for sections named `Testing`, `Tests`, `Test conventions`, or similar. Extract:
- The test command (e.g. `pytest`, `vitest`, `cargo test`, `go test ./...`, `pnpm test`).
- Required services (PostgreSQL, Redis, etc.) — listed under "integration" or "test prerequisites".
- Docstring/test-naming pattern (e.g., GIVEN/WHEN/THEN).

If none are documented, fall back to canonical detection by manifest file:
- `pyproject.toml` → `pytest` (most common)
- `package.json` → look at `scripts.test`; otherwise `pnpm test` / `npm test` / `yarn test`
- `Cargo.toml` → `cargo test`
- `go.mod` → `go test ./...`

If neither documentation nor manifest indicate a test stack, **ask the user** rather than guessing.

### 2. Check service prerequisites

If the repo's docs declare integration-test services (DB, cache, queue):
- Probe quick connectivity (`pg_isready`, `redis-cli ping`, etc.) — but only if the corresponding CLI is on PATH.
- If unreachable, print a one-line setup hint (typically `docker compose up -d`) and offer to run only unit tests via the framework's filter (`-k "not integration"`, `--testPathIgnorePatterns`, etc.).

### 3. Execute and stream output

Run the resolved command, streaming output. After completion print a structured summary:

```
Test run: <N passed>, <M failed>, <K skipped>
├ Duration: <s>
├ Coverage: <%>   # if reported
├ Unit:        <pass/fail>
└ Integration: <pass/fail>
```

### 4. On failures

For each failing test:
- Print its location and one-line failure description.
- Suggest narrow follow-ups: re-run a single test, check service state, return to `/dd:build:code` if the implementation is incomplete.

### 5. Soft convention check (optional)

If the repo's `CLAUDE.md` mandates a docstring/comment convention (e.g. GIVEN/WHEN/THEN), grep for tests missing it and list them as TODOs — **not** failures.

## Guardrails

- Never silently skip integration tests when the user asked for the full suite.
- Never bypass failing tests to commit — gate F (impl → PR) requires green.
- Do not guess a test command if neither docs nor manifest is conclusive — ask.
- Do not assume PostgreSQL/Redis are running; probe before relying on them.
