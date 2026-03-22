# Session Handoff — 2026-03-22

## Branch
`main` — merged from `consolidation/v1.1`, pushed to TestFlight as build 49 (2.0).

## What Was Done This Session

Massive polish session — 40+ items completed across two days.

### Highlights
- Unified side panel (thumbnails + info tabs, configurable L/R, icons)
- Full postcode-to-town/county lookup (9,603 sectors from ONS ONSPD)
- Address card editing: overrides persist, type changes work, live NHS lookup
- Recipient tick boxes (To/CC/None per verified card)
- Letter template: footer on every page, slim header, MRN field
- Work list: pre-download, loading spinner, multi-add picker, back-to-list button
- Name handling: title case, O'Brien, McDonald
- Folder/document name sanitisation
- Settings: appearance, panel position, macOS Settings scene
- GitHub Issues: 20 items migrated, labels created, stale branches/PRs cleaned

### Key Lessons Learned
- NavigationPath clear+append is unreliable inside navigation destination (SwiftUI limitation)
- Search index tokenises on hyphens — use direct file scan for exact lookups
- Always check #if os() guards when debugging platform-specific issues
- @State fields and let properties can desync in SwiftUI — use @State consistently for display

## Current State

- **Branch:** `main`
- **Version:** 2.0 (build 49 on TestFlight, build 50 pending)
- **GitHub Issues:** 16 open
- **Devon:** Retired (iCloud sync node only)

## What's Next

See GitHub Issues for full backlog. Priorities:
1. **#5 Envelope window alignment** — bring measurements from work
2. **#4 Sender details in Settings UI** — essential for other users
3. **#3 Performance** — measure with Instruments
4. **#14 iOS compose** — the big one
