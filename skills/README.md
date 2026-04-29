# skills/

Reusable Claude Code skills shipped by Drydock. Each skill lives in its own kebab-case directory containing a `SKILL.md` file with YAML frontmatter (`name`, `description`) and the skill body.

Skills are designed to be **standalone-invokable** — a user can call `/<skill-name>` directly without going through a Drydock command wrapper. Where a `/dd:*` command exists, it is a thin wrapper that resolves paths and arguments, then delegates to the skill.

## Requirements skills

| Skill | One-liner |
|-------|-----------|
| `vision-and-scope`        | Create a Wiegers-style Vision and Scope document |
| `use-case`                | Write a Wiegers/Cockburn use case |
| `stakeholder-profile`     | Create a Wiegers stakeholder profile |
| `requirements-elicitation`| Plan how to elicit requirements (who, what gaps, which techniques) |
| `requirements-review`     | Review requirements against the eight Wiegers quality criteria |
| `adr`                     | Create an Architectural Decision Record with auto-numbering |

## Build skills (OpenSpec)

| Skill | One-liner |
|-------|-----------|
| `openspec-new-change`       | Scaffold a new OpenSpec change |
| `openspec-continue-change`  | Advance the next missing artifact in an in-flight change |
| `openspec-apply-change`     | Implement tasks from an active change, checking items as they complete |
| `openspec-ff-change`        | Fast-forward: generate all change artifacts in one pass |
| `openspec-explore`          | Q&A mode for ambiguous scope, anchored to a change |
| `openspec-verify-change`    | Pre-archive verification — tasks all checked, deltas consistent |

## Feature skills

| Skill | One-liner |
|-------|-----------|
| `feature-orchestrate`   | Walk one idea through all ten Drydock phases — raw → explore → clarify → issue+change → branch → architect → design+tasks → code → test → draft PR. Pauses at each checkpoint. Wrapped by `/dd:feature` |
| `feature-clarify`       | Structured clarifying-questions round — each question presented with one recommended answer, 2–4 alternatives, a `[d] discuss` escape, and a `[?] defer to Open Questions` option |

## Ship skills (OpenSpec)

| Skill | One-liner |
|-------|-----------|
| `openspec-archive-change`   | Archive a completed change |
| `openspec-sync-specs`       | Sync delta specs from a change into main `openspec/specs/` |
| `openspec-bulk-archive`     | Archive multiple completed changes in one pass |

## Layout

```
skills/
└── <skill-name>/
    ├── SKILL.md           # frontmatter + body (required)
    ├── templates/         # optional — document templates the skill writes from
    └── examples/          # optional — worked examples the skill draws on
```

See [../docs/skills-catalog.md](../docs/skills-catalog.md) for invocation guidance and cross-references.
