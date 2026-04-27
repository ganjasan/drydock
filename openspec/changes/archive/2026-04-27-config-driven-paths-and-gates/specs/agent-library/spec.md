## ADDED Requirements

### Requirement: release-coordinator invocation criteria and ordering

The `release-coordinator` subagent SHALL be invoked from `/dd:ship:release` if and only if `release.repos` is declared in merged config with two or more entries. The agent SHALL compute a topological execution order from each entry's `depends_on` field using a deterministic algorithm (Kahn's, alphabetical tie-break for stability). The agent MUST detect cycles and abort with a clear cycle-detected error before any release work begins in any repo.

#### Scenario: Single-entry release.repos does not invoke agent
- **WHEN** `release.repos` declares exactly one entry and `/dd:ship:release` runs
- **THEN** the `release-coordinator` agent MUST NOT be invoked; the release proceeds in the single declared repo as if no multi-repo declaration existed

#### Scenario: Multi-entry triggers agent
- **WHEN** `release.repos` declares two or more entries and `/dd:ship:release` runs
- **THEN** the `release-coordinator` agent MUST be invoked with the full list and the originating change

#### Scenario: Topological order is deterministic
- **WHEN** the agent computes order for entries `[{name: a, depends_on: []}, {name: b, depends_on: [a]}, {name: c, depends_on: [a]}]`
- **THEN** the order MUST be exactly `[a, b, c]` (alphabetical tie-break between `b` and `c`)

#### Scenario: Cycle aborts before side effects
- **WHEN** the agent computes order for `[{name: x, depends_on: [y]}, {name: y, depends_on: [x]}]`
- **THEN** the agent MUST abort with a cycle-detected error naming `x` and `y`; no per-repo release work MUST execute in any repo
