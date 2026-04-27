## ADDED Requirements

### Requirement: paths.* and worktree.* schema documentation

`docs/extension-model.md` SHALL document the full `paths.*` and `worktree.*` schemas with types, defaults, and at least one example per top-level block.

The `paths.*` block MUST cover: `paths.requirements` (string, default `requirements/`), `paths.requirements_subdirs.{vision,stakeholders,use_cases,adr}` (strings; defaults match v0.1 layout), `paths.openspec.changes` (default `openspec/changes/`), `paths.openspec.specs` (default `openspec/specs/`), `paths.raw_root` (default `raw/`), `paths.raw_subdirs.{incoming,meetings,feedback,ideas,competitors,client_boards}` (strings; defaults match `_incoming`, `meetings`, etc.).

The `worktree.*` block MUST cover: `worktree.enabled` (bool, default `false`), `worktree.base_dir` (string, default `.worktrees/`), `worktree.naming` (template, default `wt-<issue-id>`), `worktree.branch_naming` (template, default `feature/<issue-id>-<slug>`). Supported template tokens MUST be enumerated: `<issue-id>`, `<slug>`.

#### Scenario: Schema sections present
- **WHEN** a user opens `docs/extension-model.md`
- **THEN** the document MUST contain dedicated subsections for `paths.*` and `worktree.*` listing every key above with type, default, and an example

#### Scenario: Token list present
- **WHEN** a user reads the `worktree.*` schema documentation
- **THEN** the document MUST list `<issue-id>` and `<slug>` as the supported tokens, with a note that additional tokens require a documented schema bump

### Requirement: area_to_repo edge-case documentation

`docs/extension-model.md` SHALL document `area_to_repo` with all five edge cases enumerated: (1) unset entirely → current repo, (2) set but missing requested area → fail loud, (3) value `.` → current repo, (4) absolute path → used verbatim, (5) relative path → resolved against parent of current repo. At least one worked example for each edge case MUST be present.

#### Scenario: All five edge cases documented
- **WHEN** a user reads the `area_to_repo` section of `docs/extension-model.md`
- **THEN** the document MUST contain a labeled subsection or table covering all five cases above with an example for each

### Requirement: release.* schema documentation

`docs/extension-model.md` SHALL document the full `release.*` schema: `release.gates` (list of slash-command references; covered already by `drydock-extension-model`), `release.repos` (list of `{name, path, depends_on}`; multi-repo coordination), `release.block_on_labels` (list of label strings; pre-flight blocker), `release.dry_run_default` (bool; default-to-dry-run guard). For each multi-repo example, the doc MUST include a sample `depends_on` graph and the resulting topological order.

#### Scenario: All four release keys documented
- **WHEN** a user reads the `release.*` schema documentation
- **THEN** all four keys (`gates`, `repos`, `block_on_labels`, `dry_run_default`) MUST be present with type, default, and example

#### Scenario: Multi-repo example present
- **WHEN** a user reads the `release.repos` documentation
- **THEN** the document MUST contain at least one worked example with `depends_on` declarations and the implied execution order

### Requirement: github.project_fields schema documentation

`docs/extension-model.md` SHALL document `github.project_fields.{status,priority,phase,area}` with their `id` and `options` shape, including a worked example showing how to derive `id` and `options` values via `gh project field-list --format json`.

#### Scenario: Field schema and derivation example present
- **WHEN** a user reads the `github.project_fields` section
- **THEN** the document MUST show the `{id, options}` shape for each of the four fields and include a copy-pasteable `gh project field-list` invocation that produces the values

### Requirement: Templates skeleton extended with formalized schema

`templates/extension/config.yaml` SHALL contain commented examples for every key documented above: full `paths.*`, full `worktree.*`, `area_to_repo` with all five edge-case forms shown as commented examples, full `release.*` (including a multi-repo example), full `github.project_fields`. All examples MUST use universal placeholder values (no organization or product names).

#### Scenario: Templates cover formalized schema
- **WHEN** a user inspects `templates/extension/config.yaml`
- **THEN** every documented key in the formalized schema MUST appear at least once as a commented example with a universal placeholder value

#### Scenario: Templates remain universal
- **WHEN** an inspector greps `templates/extension/config.yaml` for any client/product name
- **THEN** zero matches MUST be found
