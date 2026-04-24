# Migration from APZ

If you are coming from the internal Apilize APZ plugin, this guide maps the familiar commands and paths to their Shipwright equivalents.

> **Status:** this document is a roadmap for v0.1 — it will be finalized when the actual command port happens. Paths below reflect the planned structure.

## Command mapping

| APZ command                | Shipwright command              | Notes                                                         |
|----------------------------|---------------------------------|---------------------------------------------------------------|
| `/apz:status`              | `/sw:status`                    | 1:1                                                           |
| `/apz:next`                | `/sw:next`                      | 1:1                                                           |
| `/apz:req:vision`          | `/sw:req:vision`                | Apilize-specific paths (`apilize-hub/requirements/vision/…`) removed; defaults to `requirements/vision/` in current repo |
| `/apz:req:use-case`        | `/sw:req:use-case`              | 1:1                                                           |
| `/apz:req:stakeholder`     | `/sw:req:stakeholder`           | 1:1                                                           |
| `/apz:req:adr`             | `/sw:req:adr`                   | Auto-numbering moves from Apilize-specific counter to per-repo `requirements/adr/` counter |
| `/apz:req:review`          | `/sw:req:review`                | 1:1                                                           |
| `/apz:build:start`         | `/sw:build:start`               | No longer assumes Apilize multi-repo layout; operates on current repo |
| `/apz:build:explore`       | `/sw:build:explore`             | 1:1                                                           |
| `/apz:build:design`        | `/sw:build:design`              | 1:1                                                           |
| `/apz:build:code`          | `/sw:build:code`                | 1:1                                                           |
| `/apz:build:test`          | `/sw:build:test`                | Per-repo conventions (read from `CLAUDE.md`)                  |
| `/apz:ship:pr`             | `/sw:ship:pr`                   | No longer hardcodes Apilize Project #2; universal `gh` calls  |
| `/apz:ship:archive`        | `/sw:ship:archive`              | 1:1                                                           |
| `/apz:ship:release`        | `/sw:ship:release`              | Single-repo by default; multi-repo coordination is optional   |
| `/apz:ship:conformance`    | —                               | Apilize-specific (Apilize Protocol conformance tests). Stays in APZ. |
| `/apz:ship:parity`         | —                               | Apilize-specific (model parity). Stays in APZ.                |
| `/apz:plan:add`            | `/sw:plan:add`                  | Labels/templates become configurable; Apilize defaults removed |
| `/apz:plan:triage`         | `/sw:plan:triage`               | 1:1                                                           |
| `/apz:plan:promote`        | `/sw:plan:promote`              | Area → repo routing becomes configurable (not hardcoded)      |
| `/apz:raw:*`               | —                               | Raw-content ingestion (meetings, gmail, calendar, notion, linear) is Apilize-hub-specific. Stays in APZ. |

## Path mapping

| APZ path                                          | Shipwright equivalent                                  |
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

After Shipwright v0.1, APZ becomes a **thin Apilize-specific layer** on top of Shipwright:

- Raw-content ingestion (meetings, client emails, calendar, etc.) — these depend on Apilize's `raw/_incoming/` structure and external tracker integrations.
- Apilize Protocol conformance and parity tests.
- Client-specific workflows (WertXpert, INTREAL, etc.) that must never leave the hub.
- Apilize Project #2 board integration specifics.

Everything else is pulled up into Shipwright.

## Timeline

1. **Shipwright v0.1** — universal core extracted, command suite ported.
2. **APZ next release** — refactor to depend on Shipwright, keep only Apilize-specific additions.
3. **Ongoing** — new methodology features land in Shipwright first; APZ inherits automatically.
