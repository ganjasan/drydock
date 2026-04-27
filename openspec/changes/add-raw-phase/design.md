## Context

The `raw` phase already exists in the soon-to-retire APZ plugin under `apilize-hub/plugins/apz/commands/raw/`: nine commands plus a `raw-classifier` subagent, all working against the `apilize-hub/raw/_incoming/` directory layout. Apilize-specific defaults are baked into the command files: Gmail filters naming specific clients, Notion DB IDs, Linear team filters, the exact category list in the classifier prompt.

ADR-0004 reframes raw ingestion as universal. The `drydock-extension-model` change shipped the per-repo overlay, hook protocol, and command-reference contract that make a clean port possible. This change does the actual port:

- Pull the nine commands out of APZ and into Drydock at `commands/raw/`.
- Move the `raw-classifier` agent.
- Move the supporting skills.
- Hoist every Apilize default into a `raw.*` config key.
- Wire `post-capture` hook invocation per item.

The constraint set:

- **No Apilize names anywhere in plugin code.** The post-port grep for "apilize", "wertxpert", "intreal" must return zero matches in `commands/raw/`, `agents/raw-classifier.md`, `skills/raw-*/`.
- **Frontmatter schema must be stable.** Existing raw entries in Apilize-hub will keep working with the new commands after `retire-apz` migrates the directory.
- **MCP servers stay external.** Drydock does not bundle Gmail/Calendar/Drive/Notion/Linear access; it relies on the user's MCP configuration. Each `/dd:raw:ingest-*` documents which MCP it expects and fails loudly if absent.
- **Categories are sensibly fixed.** The five subdirs (`meetings`, `feedback`, `ideas`, `competitors`, `client-boards`) are documented Drydock conventions; users can extend via `paths.raw_subdirs` but new categories require a new key, not a free-form list.

## Goals / Non-Goals

**Goals:**

- Nine universal `/dd:raw:*` commands, each driven by `raw.*` config.
- A universal `raw-classifier` agent that reads category routing from config, with sensible defaults baked into the agent prompt.
- A documented frontmatter schema for raw entries, used by `capture`, every `ingest-*`, and consumed by `process` and `transcribe`.
- `post-capture` hook integration per item, using the protocol from `drydock-extension-model`.
- `/dd:status` and `/dd:next` updated to recognize the raw inbox.

**Non-Goals:**

- New raw sources. Six MCP-backed ingest commands plus `capture` and `transcribe` is enough for the current set; adding sources is forward-compatible.
- A web UI or richer classifier model. The classifier remains a Claude subagent.
- Migrating the Apilize-hub raw inbox itself. That is `retire-apz`.
- Multi-repo raw inbox aggregation. One repo, one inbox.

## Decisions

### D1. Inbox layout: `raw/_incoming/` plus five classified subdirs

```
<repo>/raw/
├── _incoming/         # all freshly captured items land here
├── meetings/
├── feedback/
├── ideas/
├── competitors/
└── client-boards/
```

The leading `_` on `_incoming/` keeps it sorted to the top of any directory listing. The five classified subdirs are Drydock conventions. Custom categories require adding a new key to `paths.raw_subdirs.*` rather than extending an open list — this keeps the agent prompt and any reporting code finite and reviewable.

Alternatives considered:

- **Free-form classification (any subdir name allowed).** Rejected: hard to write a status command, hard to prompt the classifier, easy for users to make typos that fragment their inbox.
- **Single flat `raw/` with frontmatter `category: ...`.** Rejected: filesystem layout is the most useful index a human has for raw content; flattening it strips that affordance.

### D2. Frontmatter schema for raw entries

Required keys:
- `source: <gmail|calendar|drive|notion|linear|github|manual>` — provenance.
- `captured_at: <ISO 8601 datetime>` — when Drydock filed this item.
- `dedup_key: <string>` — deterministic per-item identifier (e.g. `gmail:<msg-id>`, `notion:<page-id>`, `manual:<sha-of-body>`). Collisions are merged, not duplicated.

Optional:
- `parties: [...]` — people mentioned (emails or names).
- `links: [...]` — URLs referenced.
- `attachments: [...]` — paths to files (e.g. drive recording).
- `traces_to: ...` — bidirectional links to requirements/issues that this item informs.
- `original_at: <ISO 8601>` — the time the source itself recorded (e.g. email send time).

`process` rewrites items, preserving frontmatter; `dedup_key` is the merge axis.

### D3. Source-specific defaults live entirely in `raw.<source>.*` config

Every filter, label, query, ID, or look-back window the APZ commands hardcoded becomes a `raw.<source>.*` key with a documented default and an example in `templates/extension/config.yaml`. The command files themselves are universal: they read `raw.<source>.*` and pass it to the corresponding MCP tool.

For example, `/apz:raw:ingest-gmail` today contains a literal Gmail query string; `/dd:raw:ingest-gmail` reads `raw.gmail.query` and `raw.gmail.labels_to_track` from merged config. The default `raw.gmail.query` is `is:unread` (a sensible universal default); Apilize-hub overrides it in its per-repo config.

### D4. Classifier categories are configurable but bounded

The `raw-classifier` agent reads its category routing from `raw.classifier.categories` (default: the five canonical categories with documented descriptions). Users can refine descriptions or add categories, but the agent prompt template requires each category to have a name and a one-sentence description so the LLM has something to ground on.

If a config provides fewer than two categories, the classifier rejects the configuration as not useful enough to classify against — fail fast rather than produce garbage.

### D5. MCP server presence is detected, not assumed

Each `/dd:raw:ingest-*` command starts by checking that the corresponding MCP server is connected (via `/mcp list` style probe). If the MCP is missing, the command fails immediately with a message: "Gmail MCP is not connected. Install via … and re-run." It does not silently skip or retry.

Drydock cannot install MCPs for the user; it can only fail clearly. Users wire MCPs through Claude Code's standard configuration.

### D6. `dedup_key` collision strategy: merge frontmatter, append body

When `process` finds two items with the same `dedup_key`:
- Frontmatter merges: union of `parties`, `links`, `attachments`, `traces_to`. Earliest `original_at` wins. Earliest `captured_at` wins.
- Body sections concatenate with a `--- duplicate captured at <captured_at> ---` separator.
- The merged item lands in the appropriate classified subdir; both originals are deleted from `_incoming/`.

This keeps history without spreading it across files. A `--strict` flag (off by default) refuses to merge when bodies differ materially.

### D7. `process` cross-link heuristic: dedup_key + content match against requirements and issues

For each classified item, `process` searches:
- `requirements/` (vision, use cases, ADRs, stakeholder profiles) for filename or content matches against `parties`, key phrases.
- Open GitHub issues via `gh issue list` for body or title matches.

A match adds a `traces_to` entry. False positives are acceptable: a human reviews the suggestions in `process`'s output before they affect anything; the cross-link is just metadata.

### D8. Post-capture hook fires per item, not per command invocation

`/dd:raw:capture` files exactly one item and fires `post-capture` once. `/dd:raw:ingest-gmail` may file many items in one run; it fires `post-capture` after each individual item is written. This lets a `post-capture.sh` (e.g. a frontmatter-lint guard) catch each new file individually rather than getting a batch.

If a `post-capture` hook fails for one item, the failure is reported, that item is left in place (not deleted from `_incoming/`), and ingestion continues with the next item. Pre-hooks abort; post-hooks warn. Per `drydock-extension-model` D4.

### D9. `/dd:status` raw summary is a one-line count, not a listing

```
┃   Raw inbox:     12 in _incoming · last process: 4 days ago
```

A full listing belongs in `/dd:raw:process`'s preview, not in `/dd:status`. The status line is a heads-up that there is something to process.

`/dd:next` checks: if `_incoming/` count > 0, suggest `/dd:raw:process` as the next action.

## Risks / Trade-offs

- **MCP availability is out of Drydock's control.** Mitigation: fail fast with install guidance; document the MCP requirement in each ingest command's description.
- **Frontmatter schema becomes a stability surface.** Mitigation: documented in `docs/extension-model.md` § raw; additions only in v0.x; renames require a major version.
- **`dedup_key` choice is per-source and must be deterministic.** Mitigation: documented per source; the default schemes (`gmail:<msg-id>`, `notion:<page-id>`, etc.) are stable identifiers from the source itself, not derived from mutable content.
- **Some users may want raw without classification.** They can ignore `/dd:raw:process`. Items in `_incoming/` are valid Drydock state; classification is an optimization for retrieval.
- **Six MCPs is a lot of moving parts.** Mitigation: each ingest command is independent; users only need MCPs for sources they actually want to ingest. The default `<repo>/.drydock/config.yaml` ships every source key commented-out so nothing fires until configured.

## Migration Plan

This is an additive change in Drydock. No Drydock-internal code is removed. The follow-on migration of Apilize-hub's existing raw inbox happens in `retire-apz`:

- Apilize-hub already has `apilize-hub/raw/...` populated by APZ. After this change ships:
  - Apilize-hub adds `apilize-hub/.drydock/config.yaml` with `paths.raw_root: raw/` and the existing filter sets under `raw.gmail.*`, `raw.calendar.*`, etc.
  - Existing items continue working with `/dd:raw:process` and `/dd:raw:transcribe` because the frontmatter schema is unchanged from APZ's.
  - APZ commands and the apz `raw-classifier` agent are deleted in `retire-apz`.

Rollback: revert the change. The `commands/raw/` directory is wholly new; deletion is non-destructive.

## Open Questions

- **Should `/dd:raw:transcribe` be a separate command or a step inside `/dd:raw:ingest-drive`?** — Decision: separate command. Transcription is a heavyweight operation (cost, time) and may target items not yet in Drive. The split keeps `ingest-drive` fast.
- **Where do non-MCP sources go (e.g. RSS, custom webhooks)?** — Out of scope for v0.2. Users can use `/dd:raw:capture` manually or pipe through a custom shell script that calls Drydock. Adding a generic `/dd:raw:ingest-from-stdin` is a candidate for v0.3 if usage demands it.
- **Default category descriptions: include them in the agent prompt or load from config every run?** — Decision: load from config every run, with documented defaults in the agent prompt as fallback. This means projects with custom categories (e.g. an open-source project might want `bug-reports`, `feature-requests`) configure once and the agent adapts.
- **Should `process` move items atomically (mv) or copy-then-delete?** — Decision: mv. Atomic on local filesystems; failures leave items in `_incoming/` for retry. No partial-classified state.
