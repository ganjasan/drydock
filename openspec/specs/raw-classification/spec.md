# raw-classification Specification

## Purpose

Defines the `/dd:raw:process` command, the `raw-classifier` agent, the classification rules (categories and routing), the deduplication strategy for items sharing a `dedup_key`, the cross-link heuristic to existing requirements and GitHub issues, and the backlog-suggestion output format. Sits on top of the `raw-ingestion` capability — process operates on whatever the inbox currently contains.

## Requirements

### Requirement: /dd:raw:process command

The `/dd:raw:process` command SHALL classify each item in `<repo>/<paths.raw_root>/_incoming/` into one of the categories defined by `raw.classifier.categories`, deduplicate against existing inbox content, cross-link to existing requirements and open GitHub issues, and move classified items into the matching subdirectory under `<repo>/<paths.raw_root>/`. The command MUST present a preview of all proposed moves and cross-links before applying them, and MUST require user confirmation when run interactively.

#### Scenario: Preview before apply
- **WHEN** `/dd:raw:process` is invoked interactively with five items in `_incoming/`
- **THEN** the command MUST print a preview listing each item's proposed destination subdirectory and any proposed `traces_to` cross-links, and MUST wait for user confirmation before moving any files

#### Scenario: Items move atomically
- **WHEN** the user confirms the preview
- **THEN** each item MUST be moved (filesystem `mv`) to its destination subdirectory; on a per-item failure, the item MUST remain in `_incoming/` and processing of the remaining items MUST continue

#### Scenario: Empty inbox
- **WHEN** `/dd:raw:process` is invoked with an empty `_incoming/` directory
- **THEN** the command MUST report "raw inbox is empty" and exit successfully without prompting

### Requirement: raw-classifier subagent

Drydock SHALL ship the `raw-classifier` subagent under `agents/raw-classifier.md`. The agent SHALL accept a list of items (paths or content) plus the active category list (from `raw.classifier.categories`, with documented defaults if unset), and SHALL return for each item a category assignment plus a one-sentence rationale. The agent prompt MUST require each category to have a name and a one-sentence description so the LLM has explicit grounding.

#### Scenario: Default categories used when config is absent
- **WHEN** `/dd:raw:process` invokes the classifier and `raw.classifier.categories` is unset
- **THEN** the classifier MUST use the documented default categories: `meetings`, `feedback`, `ideas`, `competitors`, `client-boards`, each with its documented description

#### Scenario: Custom categories accepted
- **WHEN** `raw.classifier.categories` declares categories `[bug-reports, feature-requests, support-questions]` with descriptions
- **THEN** the classifier MUST classify into those categories only and not the defaults

#### Scenario: Insufficient categories rejected
- **WHEN** `raw.classifier.categories` declares fewer than two categories
- **THEN** the classifier MUST refuse to run and report that at least two categories are required

### Requirement: Deduplication strategy

When `/dd:raw:process` encounters multiple items with the same `dedup_key`, it SHALL merge them into a single item: frontmatter `parties`, `links`, `attachments`, and `traces_to` MUST be unioned; the earliest `original_at` and earliest `captured_at` MUST be preserved; bodies MUST be concatenated with a `--- duplicate captured at <captured_at> ---` separator. The merged item MUST land in the appropriate classified subdirectory; both originals MUST be removed from `_incoming/`.

#### Scenario: Two items with same dedup_key are merged
- **WHEN** `_incoming/` contains two files with `dedup_key: gmail:<abc@gmail.com>` and `/dd:raw:process` runs
- **THEN** exactly one file MUST exist after processing in the appropriate classified subdirectory; both original files MUST be removed from `_incoming/`; the merged file's frontmatter `parties` MUST be the union of both originals'

#### Scenario: Strict mode refuses to merge differing bodies
- **WHEN** `/dd:raw:process --strict` is invoked and two items share a `dedup_key` but their bodies differ materially
- **THEN** the command MUST refuse to merge and report the conflict; both items MUST remain in `_incoming/`

### Requirement: Cross-link heuristic

For each classified item, `/dd:raw:process` SHALL search `<repo>/requirements/` (vision, use cases, ADRs, stakeholder profiles) and open GitHub issues (via `gh issue list`) for matches against the item's `parties`, key phrases, or referenced links. Each match MUST be added as a `traces_to` entry in the item's frontmatter. Matches are advisory: false positives are acceptable because the user reviews the preview before any moves apply.

#### Scenario: Match against existing use case adds traces_to
- **WHEN** an item references "Dark mode toggle" and a use case `requirements/use-cases/UC-005-dark-mode-toggle.md` exists
- **THEN** the classified item's frontmatter MUST gain `traces_to.use_cases: [UC-005-dark-mode-toggle]`

#### Scenario: Match against open GitHub issue adds traces_to
- **WHEN** an item references "fix login redirect" and an open issue #42 with title "Login redirect broken on mobile" exists
- **THEN** the classified item's frontmatter MUST gain `traces_to.issues: [42]`

#### Scenario: No matches leaves traces_to empty
- **WHEN** an item has no detectable matches in requirements or open issues
- **THEN** the classified item MUST be moved without adding any `traces_to` entries (existing entries set during capture MUST be preserved)

### Requirement: Backlog-suggestion output

After classifying items into the meetings/feedback/ideas/competitors/client-boards subdirectories, `/dd:raw:process` SHALL produce a "backlog suggestions" section in its output: for each item where the classifier identifies an actionable theme not yet covered by an open issue, it suggests one `gh issue create` invocation with title and labels. Suggestions are presented for user review; the command MUST NOT auto-create issues.

#### Scenario: Suggestion produced for actionable feedback
- **WHEN** an item classified as `feedback` describes a clear feature request not present in existing open issues
- **THEN** the command MUST print a suggested `gh issue create` command with derived title and `Type: feature-request` label

#### Scenario: No suggestion for known issues
- **WHEN** an item already has a `traces_to.issues` entry from cross-linking
- **THEN** the command MUST NOT suggest creating a new issue for the same theme
