# Pending: Devon Local SQLite Rebuild

## Priority: High (implement immediately after JSON sync layer)

## Context
The JSON sync layer (`.addresses/*.json` in iCloud) replaces `addresses.db` as the source of truth.
However, Devon needs a local (non-iCloud) SQLite database rebuilt from these JSONs for:

1. **Letter system** — currently in design phase, will need cross-document address queries
   (e.g. "find all patients with this GP", "lookup patient by postcode")
2. **Any future power queries** that don't work well with file-per-document JSON reads

## Implementation
- Script on Devon that scans `.addresses/*.json` and rebuilds a local SQLite
- Run on demand, via cron, or triggered by fswatch on the `.addresses/` directory
- Database lives outside iCloud (e.g. `/Users/devon/Data/addresses_cache.db`)
- This is a read-only derived cache — JSONs remain the source of truth

## Depends On
- JSON sync layer being complete and deployed (Steps 1-5 of the plan)
