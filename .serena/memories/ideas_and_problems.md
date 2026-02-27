# Ideas & Problems

Quick-capture list for things that come to mind mid-task.

\1
7. **Address extraction could use metadata.fullText as fallback/cross-check** — Currently reads only from `.ocr_results/` JSON (structured, per-page). `fullText` is flat but sufficient for basic pattern matching (postcodes, names, DOBs). Could validate backend OCR vs on-device OCR, fall back when JSON missing, or boost confidence when both agree. Logged 2026-02-22.

## Ideas

1. **Connected scanner support on macOS** -- Interesting but out of scope. Bulk scanning from a connected scanner is more of a DevonTHINK use case. We are not trying to compete with or be as complex as that. Would also need external LLM integration to be truly useful (auto-classify, auto-title, auto-folder scanned pages). Park indefinitely unless the product direction changes. Logged 2026-02-25.