# Migration from APZ

If you are coming from the internal Apilize APZ plugin, this guide maps the familiar commands and paths to their Drydock equivalents.

## Command mapping

| APZ command                | Drydock command              | Notes                                                         |
|----------------------------|---------------------------------|---------------------------------------------------------------|
| `/apz:status`              | `/dd:status`                    | 1:1                                                           |
| `/apz:next`                | `/dd:next`                      | 1:1                                                           |
| `/apz:req:vision`          | `/dd:req:vision`                | Apilize-specific paths (`apilize-hub/requirements/vision/…`) removed; defaults to `requirements/vision/` in current repo |
| `/apz:req:use-case`        | `/dd:req:use-case`              | 1:1                                                           |
| `/apz:req:stakeholder`     | `/dd:req:stakeholder`           | 1:1                                                           |
| `/apz:req:adr`             | `/dd:req:adr`                   | Auto-numbering moves from Apilize-specific counter to per-repo `requirements/adr/` counter |
| `/apz:req:review`          | `/dd:req:review`                | 1:1                                                           |
| `/apz:build:start`         | `/dd:build:start`               | No longer assumes Apilize multi-repo layout; operates on current repo |
| `/apz:build:explore`       | `/dd:build:explore`             | 1:1                                                           |
| `/apz:build:design`        | `/dd:build:design`              | 1:1                                                           |
| `/apz:build:code`          | `/dd:build:code`                | 1:1                                                           |
| `/apz:build:test`          | `/dd:build:test`                | Per-repo conventions (read from `CLAUDE.md`)                  |
| `/apz:ship:pr`             | `/dd:ship:pr`                   | No longer hardcodes Apilize Project #2; universal `gh` calls  |
| `/apz:ship:archive`        | `/dd:ship:archive`              | 1:1                                                           |
| `/apz:ship:release`        | `/dd:ship:release`              | Single-repo by default; multi-repo coordination is optional   |
| `/apz:ship:conformance`    | —                               | Apilize-specific (Apilize Protocol conformance tests). Stays in APZ. |
| `/apz:ship:parity`         | —                               | Apilize-specific (model parity). Stays in APZ.                |
| `/apz:plan:add`            | `/dd:plan:add`                  | Labels/templates become configurable; Apilize defaults removed |
| `/apz:plan:triage`         | `/dd:plan:triage`               | 1:1                                                           |
| `/apz:plan:promote`        | `/dd:plan:promote`              | Area → repo routing becomes configurable (not hardcoded)      |
| `/apz:raw:*`               | —                               | Raw-content ingestion (meetings, gmail, calendar, notion, linear) is Apilize-hub-specific. Stays in APZ. |

## Path mapping

| APZ path                                          | Drydock equivalent                                  |
|---------------------------------------------------|--------------------------------------------------------|
| `apilize-hub/requirements/vision/`                | `<repo>/requirements/vision/`                          |
| `apilize-hub/requirements/stakeholders/`          | `<repo>/requirements/stakeholders/`                    |
| `apilize-hub/requirements/adr/`                   | `<repo>/requirements/adr/`                             |
| `apilize-hub/requirements/use-cases/`             | `<repo>/requirements/use-cases/`                       |
| `apilize-hub/raw/_incoming/` (and subfolders)     | — (no universal equivalent; APZ-only)                  |
| `apilize-hub/framework/`                          | `<repo>/docs/` (methodology, workflow, catalog)        |
| `apilize-hub/openspec/changes/`                   | `<repo>/openspec/changes/`                             |
| `apilize-hub/openspec/specs/`                     | `<repo>/openspec/specs/`                               |

## What stays in APZ

After Drydock v0.1, APZ becomes a **thin Apilize-specific layer** on top of Drydock:

- Raw-content ingestion (meetings, client emails, calendar, etc.) — these depend on Apilize's `raw/_incoming/` structure and external tracker integrations.
- Apilize Protocol conformance and parity tests.
- Client-specific workflows (WertXpert, INTREAL, etc.) that must never leave the hub.
- Apilize Project #2 board integration specifics.

Everything else is pulled up into Drydock.

## Timeline

1. **Drydock v0.1** — universal core extracted, command suite ported.
2. **APZ next release** — refactor to depend on Drydock, keep only Apilize-specific additions.
3. **Ongoing** — new methodology features land in Drydock first; APZ inherits automatically.
