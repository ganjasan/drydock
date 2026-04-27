---
name: raw-ingest-calendar
description: Pull Google Calendar events into the raw inbox via the Calendar MCP. Calendars and time window come from raw.calendar.* config. Standalone-invokable; also wrapped by /dd:raw:ingest-calendar.
---

You are the raw-ingest-calendar skill. Bulk-ingest calendar events as raw items.

## Setup

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

## Procedure

1. **MCP detection**: Google Calendar MCP must be connected. Absent → fail with install guidance.

2. **Read config**:
   ```bash
   calendars="$(cfg_array_get raw.calendar.calendar_ids)"
   look_back="$(cfg_get raw.calendar.look_back_days)"     # default 7
   look_ahead="$(cfg_get raw.calendar.look_ahead_days)"   # default 14
   ```
   Empty `calendars` → abort: "raw.calendar.calendar_ids must be configured."

3. **Pull events** in window `[now - look_back, now + look_ahead]` from each calendar id.

4. **For each event**:
   - `dedup_key`: `calendar:<event-id>`. Skip if exists.
   - Filename: `${start_date:0:10}_calendar_$(fm_slug "${title}").md`.
   - Frontmatter: `source: calendar`, `captured_at`, `dedup_key`, `original_at: <event start>`, `parties: [organizer, attendees]`, `links: [meet/hangout, description URLs]`, `attachments`, `topics: []`, `proposed_category: meetings`, `calendar.{calendar_id, start, end, location, recurrence}`, `traces_to: {}`.
   - Body: title, when, where, attendees, description (HTML→md).
   - Fire `dd_hook_invoke post-capture` with `{item_path, source: "calendar"}`.

5. **Report**: ingested / skipped / error counts.

## Guardrails

- Calendar IDs and window from `raw.calendar.*` only.
- For recurring events, ingest individual instances within the window; not the master.
- Dedup by stable event-id; never overwrite.
