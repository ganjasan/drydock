# Migration from APZ

The internal **APZ** plugin is being **fully retired** in Drydock v0.2 (see [ADR-0004](../requirements/adr/0004-universal-workflow-and-project-extensions.md)). Every command, skill, agent, hook, and configuration value previously living in `apilize-hub/plugins/apz/` migrates to one of two places:

- **Drydock itself** — for anything universal (the full `raw → req → plan → build → ship` workflow).
- **The consuming repo's `.drydock/` and `.claude/commands/` directories** — for anything project-specific (Gmail filters, area routing, conformance/parity tests, public-ready guards).

There is no APZ-as-thin-layer. After v0.2 the only plugin in use is `drydock`.

## Command mapping

| APZ command                  | Drydock equivalent                                          | Notes                                                                                                  |
|------------------------------|----------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| `/apz:status`                | `/dd:status`                                             | 1:1                                                                                                    |
| `/apz:next`                  | `/dd:next`                                               | 1:1                                                                                                    |
| `/apz:raw:capture`           | `/dd:raw:capture`                                        | Path defaults to `raw/_incoming/`; override via `paths.raw_root` in `<repo>/.drydock/config.yaml`      |
| `/apz:raw:process`           | `/dd:raw:process`                                        | `raw-classifier` agent moves into Drydock                                                              |
| `/apz:raw:ingest-gmail`      | `/dd:raw:ingest-gmail`                                   | Filters move from APZ defaults to `raw.gmail.filters` in `config.yaml`                                 |
| `/apz:raw:ingest-calendar`   | `/dd:raw:ingest-calendar`                                | Calendar IDs / look-ahead/back windows → `raw.calendar.*`                                              |
| `/apz:raw:ingest-drive`      | `/dd:raw:ingest-drive`                                   | Drive folder IDs / file types → `raw.drive.*`                                                          |
| `/apz:raw:ingest-notion`     | `/dd:raw:ingest-notion`                                  | Database IDs → `raw.notion.databases`                                                                  |
| `/apz:raw:ingest-linear`     | `/dd:raw:ingest-linear`                                  | Team IDs / issue filters → `raw.linear.*`                                                              |
| `/apz:raw:ingest-github`     | `/dd:raw:ingest-github`                                  | Watched repos → `raw.github.repos`                                                                     |
| `/apz:raw:transcribe`        | `/dd:raw:transcribe`                                     | 1:1                                                                                                    |
| `/apz:req:vision`            | `/dd:req:vision`                                         | Path defaults to `requirements/vision/`; override via `paths.requirements`                             |
| `/apz:req:use-case`          | `/dd:req:use-case`                                       | 1:1                                                                                                    |
| `/apz:req:stakeholder`       | `/dd:req:stakeholder`                                    | 1:1                                                                                                    |
| `/apz:req:adr`               | `/dd:req:adr`                                            | Per-repo numbering counter                                                                             |
| `/apz:req:review`            | `/dd:req:review`                                         | 1:1                                                                                                    |
| `/apz:plan:add`              | `/dd:plan:add`                                           | Labels / templates → `labels.*`, `templates.issue.*` in config                                         |
| `/apz:plan:triage`           | `/dd:plan:triage`                                        | 1:1                                                                                                    |
| `/apz:plan:promote`          | `/dd:plan:promote`                                       | Area → repo routing → `area_to_repo` map in config                                                     |
| `/apz:build:start`           | `/dd:build:start`                                        | No assumption of multi-repo layout; routing comes from config                                          |
| `/apz:build:explore`         | `/dd:build:explore`                                      | 1:1                                                                                                    |
| `/apz:build:design`          | `/dd:build:design`                                       | 1:1                                                                                                    |
| `/apz:build:code`            | `/dd:build:code`                                         | 1:1                                                                                                    |
| `/apz:build:test`            | `/dd:build:test`                                         | Conventions read from per-repo `CLAUDE.md`                                                             |
| `/apz:ship:pr`               | `/dd:ship:pr`                                            | Project number / fields → `github.project*` in config; pre-pr guard runs from `.drydock/hooks/pre-pr.sh` |
| `/apz:ship:archive`          | `/dd:ship:archive`                                       | 1:1                                                                                                    |
| `/apz:ship:release`          | `/dd:ship:release`                                       | Conformance/parity move into `release.gates` (see below)                                               |
| `/apz:ship:conformance`      | `<repo>/.claude/commands/conformance.md`, listed in `release.gates` | Apilize-Protocol-specific runner becomes a project-local slash command in the protocol repo            |
| `/apz:ship:parity`           | `<repo>/.claude/commands/parity.md`, listed in `release.gates` | Same model as conformance                                                                              |

## Hook mapping

| APZ hook                        | Drydock equivalent                                        | When it runs                              |
|---------------------------------|--------------------------------------------------------|-------------------------------------------|
| `frontmatter-lint.sh`           | `<repo>/.drydock/hooks/post-capture.sh`                | After `/dd:raw:capture` writes a file     |
| `public-ready-guard.sh`         | `<repo>/.drydock/hooks/pre-pr.sh`                      | Before `/dd:ship:pr` opens the PR         |
| `session-status.sh`             | `<repo>/.drydock/hooks/session-start.sh` *(if used)*   | Claude Code SessionStart event            |

## Path mapping

| APZ path                                        | Drydock equivalent                                         |
|-------------------------------------------------|-----------------------------------------------------------|
| `apilize-hub/requirements/vision/`              | `<repo>/requirements/vision/` (root via `paths.requirements`) |
| `apilize-hub/requirements/stakeholders/`        | `<repo>/requirements/stakeholders/`                       |
| `apilize-hub/requirements/adr/`                 | `<repo>/requirements/adr/`                                |
| `apilize-hub/requirements/use-cases/`           | `<repo>/requirements/use-cases/`                          |
| `apilize-hub/raw/_incoming/` (and subfolders)   | `<repo>/raw/_incoming/` (root via `paths.raw_root`)       |
| `apilize-hub/framework/`                        | `<repo>/docs/` (methodology, workflow, catalog, extension-model) |
| `apilize-hub/openspec/changes/`                 | `<repo>/openspec/changes/`                                |
| `apilize-hub/openspec/specs/`                   | `<repo>/openspec/specs/`                                  |

## Where Apilize-specific behavior lives after migration

Everything that used to be hardcoded in APZ now lives **in the Apilize repos themselves**:

```
apilize-hub/
├── .drydock/
│   ├── config.yaml          # gmail filters, calendar IDs, area_to_repo,
│   │                        # release.gates, github.project, ...
│   └── hooks/
│       ├── post-capture.sh  # ← was frontmatter-lint.sh
│       └── pre-pr.sh        # ← was public-ready-guard.sh
├── raw/                     # ingestion lands here
├── requirements/
└── openspec/

apilize-protocol/
├── .drydock/
│   └── config.yaml          # release.gates: [/conformance, /parity]
└── .claude/
    └── commands/
        ├── conformance.md   # ← was /apz:ship:conformance
        └── parity.md        # ← was /apz:ship:parity
```

The Drydock plugin code itself contains zero references to Apilize, WertXpert, INTREAL, or any other client name — that's the whole point.

## Migration steps for an Apilize-hub user

Performed once during the `retire-apz` change (in the `apilize-hub` repo, not in Drydock itself):

1. Install Drydock as the only Claude Code plugin (replace whatever route was used for APZ).
2. Create `apilize-hub/.drydock/config.yaml` from `<drydock>/config.yaml.example`. Fill in:
   - `paths.raw_root: raw/`
   - `raw.gmail.filters`, `raw.calendar.*`, `raw.notion.databases`, `raw.linear.*` (carry over the values previously baked into APZ commands).
   - `github.project` (Apilize Project #2 details).
   - `area_to_repo` (e.g. `models: ../apilize-models`, `protocol: ../apilize-protocol`, …).
   - `release.gates: [/dd:build:test]` initially; add protocol-repo specifics there.
3. Move the two hooks: `apilize-hub/.drydock/hooks/post-capture.sh` ← old `frontmatter-lint.sh`; `apilize-hub/.drydock/hooks/pre-pr.sh` ← old `public-ready-guard.sh`. Make executable.
4. In `apilize-protocol`, create `.claude/commands/conformance.md` and `.claude/commands/parity.md` carrying over the test-runner logic. Add to that repo's `.drydock/config.yaml`:
   ```yaml
   release:
     gates:
       - /dd:build:test
       - /conformance
       - /parity
   ```
5. Delete `apilize-hub/plugins/apz/` entirely.
6. Verify with `/dd:status` that the configured project, raw inbox, and active changes are all visible.

## Timeline

1. **Drydock v0.1** *(complete)* — universal core extracted, `req`/`plan`/`build`/`ship` command suites ported.
2. **Drydock v0.2** *(in progress, ADR-0004)* — pentaphase workflow, extension model, raw phase added; APZ retired in the same release window.
3. **Post-v0.2** — APZ no longer exists; new methodology features land in Drydock and apply to all consuming repos via their `.drydock/` overlays automatically.
