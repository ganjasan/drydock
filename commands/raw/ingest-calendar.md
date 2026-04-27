---
description: Pull Google Calendar events into the raw inbox (requires authenticated Google Calendar MCP)
allowed-tools: Bash, Read, Write
---

Bulk-ingest calendar events as raw items via the Google Calendar MCP. Calendars and time window come from `raw.calendar.*` config.

## Procedure

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"; dd_config_load
source "${CLAUDE_PLUGIN_ROOT}/lib/hooks.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/frontmatter.sh"
```

### 1. MCP detection

Verify Google Calendar MCP is connected. If absent: `ERROR: Google Calendar MCP is not connected. Install/authenticate, then re-run.` Exit non-zero.

### 2. Read filter config

```bash
calendars="$(cfg_array_get raw.calendar.calendar_ids)"
look_back="$(cfg_get raw.calendar.look_back_days)"   # default 7
look_ahead="$(cfg_get raw.calendar.look_ahead_days)" # default 14
```

If `calendars` is empty, abort: "raw.calendar.calendar_ids must be configured."

Compute time window: `[now - look_back_days, now + look_ahead_days]`.

### 3. Pull events

For each calendar id, call the Calendar MCP `list_events` over the window. For each event, capture: title, start/end, attendees, organizer, description, location, hangout/meet link, attachments.

### 4. For each event — write or dedup

```bash
raw_root="$(cfg_get paths.raw_root)"
incoming="${raw_root}/$(cfg_get paths.raw_subdirs.incoming)"
target_dir="<repo-root>/${incoming}"
```

For each event:

a. **`dedup_key`**: `calendar:<event-id>` (Google's stable id).

b. **Dedup**: skip if exists.

c. **Filename**: `${start_date:0:10}_calendar_$(fm_slug "${title}").md`.

d. **Frontmatter**:

```yaml
---
source: calendar
captured_at: <ISO 8601 UTC, now>
dedup_key: calendar:<event-id>
captured_by: claude-code:/dd:raw:ingest-calendar
original_at: <event start in ISO 8601>
parties: [<organizer-email>, <attendee-emails...>]
links: [<meet/hangout link>, <description-urls>]
attachments: [<attachment paths from event>]
topics: []
proposed_category: meetings
calendar:
  calendar_id: <id>
  start: <ISO 8601>
  end: <ISO 8601>
  location: <string>
  recurrence: <RRULE if any>
traces_to: {}
---

# <title>

**When:** <human-readable start–end>
**Where:** <location or meet link>
**Attendees:** <list>

<description, HTML→markdown>
```

e. **Post-capture hook** per item.

### 5. Report

```
Ingested <N> calendar event(s); skipped <M> existing (dedup); <K> errors
```

## Guardrails

- Calendar IDs and window come only from `raw.calendar.*` config.
- MCP absent → fail loudly; never silently skip ingestion.
- Dedup by stable event-id; never overwrite.
- For recurring events, prefer ingesting individual instances within the window; do not write the master event itself.
