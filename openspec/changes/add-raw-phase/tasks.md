## 1. Port command files

- [ ] 1.1 Create `commands/raw/` directory and add nine command files: `capture.md`, `process.md`, `ingest-gmail.md`, `ingest-calendar.md`, `ingest-drive.md`, `ingest-notion.md`, `ingest-linear.md`, `ingest-github.md`, `transcribe.md`
- [ ] 1.2 For each command file: copy structure from APZ counterpart, replace direct path/filter literals with config reads via `lib/config.sh`, replace agent invocation with `subagent_type: dd:raw-classifier`
- [ ] 1.3 Strip every Apilize-specific value from command files (filters, IDs, queries, label names, paths) — assert with grep that "apilize", "wertxpert", "intreal" (case-insensitive) yield zero matches
- [ ] 1.4 Wire `dd_hook_invoke post-capture` per filed item in `capture.md` and every `ingest-*.md`

## 2. Port subagent

- [ ] 2.1 Copy `apilize-hub/plugins/apz/agents/raw-classifier.md` to `agents/raw-classifier.md`
- [ ] 2.2 Replace any hardcoded category list in the agent prompt with a placeholder that loads from `raw.classifier.categories` (defaults documented in the agent prompt as fallback)
- [ ] 2.3 Strip Apilize-specific examples and rewrite with universal examples
- [ ] 2.4 Update `agents/README.md` to mention `raw-classifier` and remove the "stays in APZ" note

## 3. Port skills

- [ ] 3.1 Create `skills/raw-capture/SKILL.md` with frontmatter and prompt body
- [ ] 3.2 Create `skills/raw-process/SKILL.md`
- [ ] 3.3 Create `skills/raw-ingest-gmail/SKILL.md`
- [ ] 3.4 Create `skills/raw-ingest-calendar/SKILL.md`
- [ ] 3.5 Create `skills/raw-ingest-drive/SKILL.md`
- [ ] 3.6 Create `skills/raw-ingest-notion/SKILL.md`
- [ ] 3.7 Create `skills/raw-ingest-linear/SKILL.md`
- [ ] 3.8 Create `skills/raw-ingest-github/SKILL.md`
- [ ] 3.9 Create `skills/raw-transcribe/SKILL.md`
- [ ] 3.10 Verify each skill is standalone-invokable (the wrapper `commands/raw/<name>.md` calls into the skill, not the other way round)

## 4. Configuration schema

- [ ] 4.1 Extend `lib/config.sh` validation to recognize the `raw.*` namespace (no errors on unknown keys; documented keys checked for type)
- [ ] 4.2 Document the full `raw.*` schema in `docs/extension-model.md` § raw, listing each source's keys with types, defaults, and example values
- [ ] 4.3 Document the raw-entry frontmatter schema in `docs/extension-model.md` § raw frontmatter (required: source, captured_at, dedup_key; optional: parties, links, attachments, traces_to, original_at)
- [ ] 4.4 Extend `templates/extension/config.yaml` with a fully commented `raw.*` block (universal example values only)

## 5. Frontmatter and dedup

- [ ] 5.1 Add `lib/raw_frontmatter.sh` helper for emitting universal frontmatter from each ingest command
- [ ] 5.2 Document the per-source `dedup_key` scheme: `gmail:<msg-id>`, `calendar:<event-id>`, `drive:<file-id>`, `notion:<page-id>`, `linear:<issue-id>`, `github:<repo>#<num>`, `manual:<sha-of-body>`
- [ ] 5.3 Implement dedup check at write time: skip writing if `dedup_key` already exists anywhere under `<paths.raw_root>/`
- [ ] 5.4 Implement merge-on-collision in `/dd:raw:process` per design D6 (frontmatter union; body concatenation with separator; earliest timestamps preserved)
- [ ] 5.5 Add `--strict` flag to `/dd:raw:process` that refuses merge on materially different bodies

## 6. Cross-link heuristic in /dd:raw:process

- [ ] 6.1 Implement search across `<repo>/requirements/` for filename and content matches against item `parties`, key phrases, and links
- [ ] 6.2 Implement search across open GitHub issues via `gh issue list --state open --json number,title,body`
- [ ] 6.3 Add detected matches to `traces_to` frontmatter (advisory; user reviews preview)
- [ ] 6.4 Generate "backlog suggestions" output: `gh issue create` snippets for actionable themes not already covered by open issues

## 7. /dd:status and /dd:next integration

- [ ] 7.1 Update `commands/status.md` to add a one-line raw inbox summary (count + last-process timestamp); omit the line when no `paths.raw_root` is configured and no default `raw/` exists
- [ ] 7.2 Update `commands/next.md` to suggest `/dd:raw:process` when `_incoming/` is non-empty (priority above issue triage and new builds)

## 8. MCP detection

- [ ] 8.1 Add `lib/mcp_check.sh` helper that probes `/mcp list` for a named server and returns 0/1
- [ ] 8.2 Each `/dd:raw:ingest-*` command starts with an MCP-presence check; on missing MCP, prints a clear install-guidance message and exits non-zero
- [ ] 8.3 Document each command's MCP requirement in its frontmatter description

## 9. Tests

- [ ] 9.1 Fixture: `lib/tests/fixtures/raw_inbox/` with sample `_incoming/` items covering all six sources plus manual
- [ ] 9.2 Test classifier output: each fixture item is classified into the expected default category
- [ ] 9.3 Test dedup at write time: re-running an ingest against the same source state writes zero new files
- [ ] 9.4 Test merge-on-collision: two items with identical `dedup_key` and union-able frontmatter merge correctly
- [ ] 9.5 Test cross-link: an item referencing an existing use-case filename gains `traces_to.use_cases`
- [ ] 9.6 Test post-capture hook fires once per item (verify with a logging hook in fixture)

## 10. Documentation polish

- [ ] 10.1 Flip `docs/skills-catalog.md` raw section from "*(planned)*" to shipped; remove the "raw-classifier shipped from v0.2" note (it now is shipped)
- [ ] 10.2 Add a short example flow in `docs/workflow.md` showing actual paths (e.g. `raw/_incoming/2026-04-27-strategy-call.md`)
- [ ] 10.3 Update `commands/README.md` (if any) to list the raw namespace

## 11. Verification

- [ ] 11.1 Run `openspec validate add-raw-phase --strict` and resolve any issues
- [ ] 11.2 Run all `lib/tests/test_*.sh` — all pass, including the new raw-related tests
- [ ] 11.3 Smoke-test: in this drydock repo, run `/dd:raw:capture` interactively, file an item, verify post-capture hook fires
- [ ] 11.4 Smoke-test: configure `raw.gmail.query: "is:unread"` (with Gmail MCP available), run `/dd:raw:ingest-gmail`, verify items land with correct frontmatter
- [ ] 11.5 Smoke-test: drop a `<drydock>/.drydock/hooks/post-capture.sh` that exits non-zero and verify the warning is reported (post-* hooks warn, do not abort)
- [ ] 11.6 Final grep across `commands/raw/`, `agents/raw-classifier.md`, `skills/raw-*/`: zero matches for any client/product name
