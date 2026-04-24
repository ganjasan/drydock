# openspec/

Shipwright's OWN OpenSpec changes and specs — this is the dogfooding surface (see ADR-0002).

## Layout

- `changes/` — active and archived OpenSpec changes. Each change is a directory `YYYY-MM-DD-kebab-title/` containing `proposal.md`, `design.md`, `tasks.md`, and optionally `deltas/`.
- `specs/` — living specs, updated when changes are archived.
- `archive/` — merged changes after archival (may be a subdirectory of `changes/` depending on OpenSpec version; TBD).

## First change

The first OpenSpec change in this repository will be the port of APZ command files into Shipwright's `commands/` directory. Until then, this directory is empty by design.
