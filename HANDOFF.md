# Session Handoff — 2026-03-27

## Branch
`main` — pushed, build 51 on TestFlight (2.0).

## What Was Done This Session

### Address Card Data Model (plan at `.claude/plans/address-card-data-model.md`)
- Type-aware saves — `saveChanges()` starts clean, only writes fields the current type owns
- `ExtractedAddress.init` guards enriched data, title inference, name derivation to patient type only
- `saveOverride()` creates sub-objects conditionally by type
- Build 51 deployed to TestFlight (iOS + macOS)

### Major Housekeeping
- Deleted `AddressExtractor/` (74 files, -17,497 lines), `memory-bank/`, pruned `scripts/`
- Deleted 14 stale branches + 1 worktree + remote `consolidation/v1.1`
- Serena memories: deleted 2, rewrote 2, archived 3 to `legacy/`
- Claude memories: updated 3 (compose design, consolidation, MEMORY.md)
- Migrated all ideas/problems to GitHub Issues — single source of truth
- Filed 3 new issues (#30, #31, #32)
- Project audit written: `docs/project-audit-2026-03-27.md`

### Bug Fixes
- **#25 Restore-on-launch** — soft 5s timeout with Keep Waiting / Go Back prompt, Option-key bypass on macOS, file I/O moved off main actor
- **#28 Search bar lag** — extracted into standalone `DocumentSearchBar` struct with own `@State`, centred via `.principal` placement, plain text field (no focus ring), stable layout (opacity for clear button)
- **#30 Special chars in folder names** — already fixed (closed)
- **#32 Document auto-reload after inject** — already fixed (closed)

### Polish
- Clear button layout jump fixed in both search bar and address card editable fields (opacity instead of conditional insert/remove)

## Current State
- **Branch:** `main`
- **Version:** 2.0 (build 51 on TestFlight)
- **GitHub Issues:** 22 open, 8 closed
- **Devon:** Retired (iCloud sync node only)

## What's Next
- **#27 Multiple "Other" addresses + position field** — design questions captured in issue comment, needs design session before implementation
- **#31 iCloud override race condition** — may be less urgent post-consolidation, needs verification
- See `docs/project-audit-2026-03-27.md` section 8 for full prioritised roadmap
- `PLAN.md` still in repo — can be deleted (superseded)
