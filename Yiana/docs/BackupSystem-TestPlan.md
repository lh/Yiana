# Backup System — Test Plan (macOS Digital Paper)

This plan validates the backup model: one backup per document per local day, adjacent storage preferred, atomic writes, safe revert, and 7‑day retention.

## Scope
- First‑commit backup creation (per day, per document)
- Adjacent folder vs. app‑container fallback
- Atomic replace semantics and crash safety
- Revert to start of day
- Retention pruning (7 days default)
- Concurrency serialization (locking)
- Behavior when permissions or external edits intervene

## Preconditions
- A writable sample PDF (`Sample.pdf`) on a local volume
- Variants: read‑only location, sandboxed path requiring security‑scoped bookmark access
- App build with `BackupManager` integrated into commit flow (no UI automation required for this plan)

## Test Cases

1) First commit creates adjacent backup
- Place `Sample.pdf` in a writable folder
- Ensure no `.yiana_backups` exists next to it
- Trigger the first commit of the day
- Expect: `.yiana_backups/Sample_YYYY-MM-DD.pdf` created
- Expect: Subsequent commits on the same day DO NOT create additional backups

2) Fallback to app container when adjacent write denied
- Place `Sample.pdf` in a protected location (simulate adjacent write denial)
- Trigger first commit of the day
- Expect: Backup created under app container path (e.g., `Application Support/YianaBackups/<docId>/<YYYY-MM-DD>/Sample.pdf`)
- Expect: `hasTodayBackup` returns true

3) Atomicity on backup copy
- While backup is being created (artificially delay copy in a test build), power‑kill the app or crash it
- On next launch: no partially written backup present (either full file or none)
- Any `.tmp` artifacts are cleaned up on startup

4) Atomicity on working‑file replace
- During commit (artificially delay replace), power‑kill the app
- On next launch: working file is either fully old or fully new, never half‑written
- Any lingering `.tmp` cleared

5) Revert to start of day
- With a valid backup created today, make further commits
- Invoke revert
- Expect: Working `Sample.pdf` replaced by today’s backup (atomic)
- Expect: In‑app viewer reloads the document

6) No backup available
- With no backup for today, invoke revert
- Expect: User‑visible error “No start‑of‑day backup available for <date>”

7) Retention pruning
- Seed backups for 10 consecutive days in `.yiana_backups`
- Run prune with `retentionDays = 7`
- Expect: Files older than 7 days removed; last 7 days retained

8) Concurrency: lock serialization
- Trigger two commits quickly (e.g., two windows of the same document)
- Expect: Second waits or fails fast with lock timeout; no corruption

9) External edits detection (integration)
- Modify the working file on disk via Finder while app is open (before commit)
- Expect: App prompts to reload or save‑as‑copy (commit should not blindly overwrite)

10) Permissions and bookmarks
- With sandbox enabled, remove/document bookmark access
- Attempt backup + revert
- Expect: Clear permission error; UI path to grant access or fallback to app‑container backup only

## Acceptance Criteria
- Exactly one backup per doc per day; idempotent on repeated commits
- Revert successfully restores the start‑of‑day content, with atomic replace
- No data loss or corruption under power‑kill/crash during backup or replace
- Retention reliably prunes files older than the configured threshold
- Locking prevents concurrent write corruption

## Instrumentation
- Log: backup created (ms, location), revert success/failure, prune counts, lock waits/timeouts, IO errors
- Metric thresholds: typical backup < 100ms for small PDFs; revert < 100ms; prune proportional to file count

## Artifacts
- Test PDFs: small (2–5 pages), medium (50 pages)
- Folders: writable, read‑only, sandboxed/bookmarked

## Notes
- This plan assumes the commit pipeline calls `ensureDailyBackup` before the first flatten of the day, and that revert reloads the viewer and clears transient overlay state.

