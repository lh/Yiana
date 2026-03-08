# Ideas & Problems

Quick-capture list for things that come to mind mid-task.

\1
7. **Address extraction could use metadata.fullText as fallback/cross-check** — Currently reads only from `.ocr_results/` JSON (structured, per-page). `fullText` is flat but sufficient for basic pattern matching (postcodes, names, DOBs). Could validate backend OCR vs on-device OCR, fall back when JSON missing, or boost confidence when both agree. Logged 2026-02-22.

## Problems

8. **Special characters in folder names (`?`, `#`, `%`) corrupt file operations** — Folder `Junk?` causes documents to silently move to parent folder during save/archive operations. The `?` is likely interpreted as a URL query separator at some point in the URL→path→URL chain (e.g. `URL(fileURLWithPath:)` round-trip). Documents "vanish" from the folder and reappear in parent. Need to either sanitize folder names on creation or ensure all file operations use `.path` instead of URL string comparisons. Discovered 2026-02-28.

## Ideas

3. **Expandable Typst dashboard** — The Devon dashboard (`scripts/dashboard.typ` + `dashboard-collector.py`, served via typst-live LaunchAgent on port 5599) can be extended with any server-side metric: extraction stats, backend DB counts, iCloud sync state, log growth trends, etc. Just add to collector + template.

1. **Connected scanner support on macOS** -- Interesting but out of scope. Bulk scanning from a connected scanner is more of a DevonTHINK use case. We are not trying to compete with or be as complex as that. Would also need external LLM integration to be truly useful (auto-classify, auto-title, auto-folder scanned pages). Park indefinitely unless the product direction changes. Logged 2026-02-25.

## Work List — reverted and redesigning (2026-03-08)

All work list code reverted from Yiana (commit cd5340a). Eight attempts to fix click navigation inside `List(selection:)` failed. The feature will be reimplemented from scratch with the work list OUTSIDE the sidebar List. Full spec and architectural constraint documented in `HANDOFF.md`. Diagnostic history in `docs/work-list-navigation-failures.md`.
