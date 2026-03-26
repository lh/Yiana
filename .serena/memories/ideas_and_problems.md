# Ideas & Problems

Quick-capture list for things that come to mind mid-task.

\1
7. **Address extraction could use metadata.fullText as fallback/cross-check** — Currently reads only from `.ocr_results/` JSON (structured, per-page). `fullText` is flat but sufficient for basic pattern matching (postcodes, names, DOBs). Could validate backend OCR vs on-device OCR, fall back when JSON missing, or boost confidence when both agree. Logged 2026-02-22.

## Problems

12. **iCloud override race condition — implement before Phase 1.5** — When user edits an override on device A and device B re-extracts before sync completes, the override is lost. Fix: separate override file (`{documentId}.overrides.json`) so extraction never touches user edits. `AddressRepository` merges at read time. Must be done before retiring Python extraction (Phase 1.5). See HANDOFF.md "Open Design Question" for full analysis. Discovered 2026-03-20.

9. **Extraction misses address lines** — Real-world test (Groves_Simon_250870, single-page scan) extracted postcode RH1 4DD, patient name, DOB, and phone, but no street address lines. Likely the extractors (label/form) aren't picking up address lines from this document layout. Needs investigation in the extraction cascade. Discovered 2026-03-20.

10. **Duplicate phone numbers** — When the same phone number appears multiple times in the source document, it gets extracted multiple times. Need deduplication in phone extraction. Discovered 2026-03-20.

11. **GP data not extracted from some documents** — Groves_Simon_250870 has GP info but none was picked up by any extractor. May be a layout the extractors don't recognise. Discovered 2026-03-20.

21. **Address card UI issues (2026-03-21):**
    a. Town/city not inferred from postcode despite plan #13 existing — postcode-to-town lookup not yet implemented.
    b. Cannot add a new GP card — UI flow for adding GP addresses missing or broken.
    c. Changing patient card to GP type picks up some GP data initially, but saving reverts to prior patient data — likely the save path writes back the original extracted data rather than the edited fields. Needs investigation in AddressesView/AddressRepository save flow.

8. **Special characters in folder names (`?`, `#`, `%`) corrupt file operations** — Folder `Junk?` causes documents to silently move to parent folder during save/archive operations. The `?` is likely interpreted as a URL query separator at some point in the URL→path→URL chain (e.g. `URL(fileURLWithPath:)` round-trip). Documents "vanish" from the folder and reappear in parent. Need to either sanitize folder names on creation or ensure all file operations use `.path` instead of URL string comparisons. Discovered 2026-02-28.

## Ideas

13. **Postcode outward code → town lookup table for city extraction** — Instead of parsing city from OCR text (fragile, 50% junk in Python's results), use the already-extracted postcode to look up the town. ~2,900 UK outward codes → ~100KB static dictionary, ships in the Swift package with zero network dependency. Piggybacks on our 97.6% postcode accuracy. postcodes.io has a bulk outcodes API to build the table. Postcode sector level (~12,000 entries, ~500KB) gives more precision. Would replace all OCR-based city heuristics and eliminate junk entirely. Logged 2026-03-21. Future: build an async updater into the app itself — when a postcode sector isn't in the static table, query postcodes.io live and cache the result. Grows the table organically over time.


3. **Expandable Typst dashboard** — The Devon dashboard (`scripts/dashboard.typ` + `dashboard-collector.py`, served via typst-live LaunchAgent on port 5599) can be extended with any server-side metric: extraction stats, backend DB counts, iCloud sync state, log growth trends, etc. Just add to collector + template.

22. **Traffic light filter indicators on iPad/iPhone** — macOS version uses coloured "traffic light" dots to select/filter documents by state. Port this to iPad and iPhone. Also: suppress red/blue indicators when no documents have that state — keeps the UI clean (don't show a filter for something that doesn't exist). Logged 2026-03-21.

23. **Local peer-to-peer sync via Multipeer Connectivity / Bonjour** — Devices on the same network or Bluetooth range could sync directly without iCloud round-trip. Apple's Multipeer Connectivity (stable since iOS 7) or Bonjour + TCP. Use cases: instant draft delivery, entity DB sync, OCR offloading. Draft JSON format unchanged — just the transport. Try local peer first, fall back to iCloud. Complications: duplicate delivery (needs idempotency), ~8 peer limit, iOS background execution limits, large payload reliability. Build after consolidation is stable. Logged 2026-03-21.

20. **iPhone camera as scanner for Mac app** — Use Continuity Camera / camera capture to scan documents directly from iPhone into the macOS Yiana app. Apple provides this natively via `NSToolbarItem` continuity camera support or the `VNDocumentCameraViewController` on iOS feeding back to macOS via Handoff/iCloud. Could eliminate the need to scan on the iPhone app separately and then wait for iCloud sync. Investigate whether Continuity Camera supports multi-page document scanning or just single photos. Logged 2026-03-21.

27. **Restore last state on launch** — Remember which folder was open and which document was displayed, restore on app launch. Simple UserDefaults persistence of folder path + document URL. No new UI needed — just feels like the app remembers where you were. Logged 2026-03-22.

26. **Performance: ruthless speed improvement for note loading/exiting** — Logged 2026-03-22. Priority. The app needs to feel instant when opening and closing documents. Need to: (a) measure current load/exit times with Instruments or os_signpost, (b) identify bottlenecks (file I/O, PDF rendering, iCloud downloads, extraction, entity DB ingestion), (c) set target times (e.g. <500ms to first page visible), (d) profile real-world documents (large multi-page scans, not synthetic). Consider lazy loading (show first page before full document loads), caching (keep recently opened docs in memory), and deferring non-critical work (extraction, entity ingestion, search indexing) to after the document is visible.

24. **Visual form template builder for OCR extraction** — Logged 2026-03-22. Long-term.
    Users drag labelled building blocks onto a scanned PDF to define regions: "patient address line 1", "patient postcode", "GP name", etc. One template per form type, reused for all instances.
    **Tier 1 (in-app):** Region map feeds Vision framework's region-of-interest API. Extraction reads text from defined rectangles. No code changes per form type. Lightweight, fully on-device.
    **Tier 2 (Claude-assisted):** For complex forms, export annotated template + OCR text to Claude. User iterates with Claude to produce extraction rules/recipe. Copy result back into app. Empowers users to teach the app new form types without developer involvement.
    Key insight: inverts the extraction problem from "guess what's important" to "user shows what matters." Makes the app a platform, not a product that needs updating for every new form layout.
    Commercial parallels exist (ABBYY FlexiCapture, Rossum, etc.) but they're enterprise SaaS. A lightweight drag-and-label approach scoped to addresses/contacts would be tractable.

1. **Connected scanner support on macOS** -- Interesting but out of scope. Bulk scanning from a connected scanner is more of a DevonTHINK use case. We are not trying to compete with or be as complex as that. Would also need external LLM integration to be truly useful (auto-classify, auto-title, auto-folder scanned pages). Park indefinitely unless the product direction changes. Logged 2026-02-25.

## Swift Extraction Service on Devon (logged 2026-03-14)

**Goal:** Replace Python extraction service + backend DB + letter generator with Swift equivalents on Devon.

**Why:**
- Mac mini already has NLTagger, NSDataDetector, Vision — better than Python regex cascade
- OCR service is already Swift; one language simplifies deployment and maintenance
- Eliminates Python venv/PYTHONPATH/launchd headaches
- NLTagger+NSDataDetector parser (90 lines) already outperforms Python regex extractors

**Approach:**
- Build Swift extraction service alongside existing Python — run both in parallel, compare outputs
- No need to take Python down until Swift is proven
- Backend DB: GRDB.swift (already approved dependency)
- Letter generator: port last (most complex, lowest priority)

**Blocker:** Devon runs older macOS. NLTagger NER needs macOS 10.14+ (should be fine). NSDataDetector since 10.7. Check Devon's exact macOS version before starting. Tahoe upgrade possible but painful — only needed for Apple Intelligence, not for core NLP frameworks.

**Scope:** extraction_service.py, address_extractor.py, spire_form_extractor.py, backend_db.py, letter_generator.py, letter_system_db_simple.py

17. **Document doesn't auto-reload after InjectWatcher appends PDF** — InjectWatcher appends the hospital records PDF to the .yianazip on disk, but the in-memory NoteDocument doesn't detect the external file change. User must close and reopen the document to see the appended page. Fix: either watch for file modifications (NSFilePresenter / NSDocument revert), or have InjectWatcher post a notification that the document view observes and triggers a reload. Discovered 2026-03-21.

18. **Typst replaces LaTeX for letter rendering** — Rust crate `yiana-typst-bridge` and Swift package `YianaRenderer` built and tested. Compiles Typst templates to PDF via FFI (no subprocess). XCFramework for macOS + iOS. 30ms to render 3 PDFs. Next: wire into Yiana app (Milestone 3) then retire Devon render service (Milestone 4). Logged 2026-03-21.

19. **Letter formatting finessing needed** — Logged 2026-03-21, updated 2026-03-23.
    a. **Envelope window alignment** — NEEDS REDESIGN. Calibration grid method worked (window at 15-115mm x 55-90mm from page edge). Multiple template iterations degraded quality. Current state: postal copies have no sender header, body indented below fold, but layout needs a fresh attempt. Consider Option B (address on obverse/page 2) as cleaner alternative. Do in a dedicated session with fresh eyes.
    b. **Footer contact block** — DONE. Secretary + hospital/address/phone on every page.
    c. **Custom/user-editable templates** — When the app is generalised beyond medical/personal use, users will need to write or adapt their own Typst templates. Design TBD — could be template selection, in-app editor, or user-supplied .typ files. Long-term product consideration.

16. **HTML render template: leading comma when department is empty** — `sender.json` has `"department": ""`. The HTML footer template joins role/department/hospital without filtering empties, producing `, Spire Gatwick Park Hospital`. PDF render (LaTeX) handles it correctly. Low priority — cosmetic, HTML-only. Logged 2026-03-21.

25. **Click NHS candidate to adopt as GP contact** — NHS lookup candidates already show in GP cards. Add tap gesture to fill gpName, gpPractice, gpAddress, gpPostcode, gpOdsCode from the selected candidate. Enters edit mode if not already editing. Small change — data is already there. Logged 2026-03-22.

31. **Sender details in Settings UI** — Currently sender config is a manually created `sender.json` in iCloud (`.letters/config/`). No UI to edit it. Add a Sender Details section in Settings: name, credentials, role, department, hospital, address, phone, email, secretary (name/phone/email). Saves via SenderConfigService. First launch should prompt to fill in. Essential for other users — they can't hand-edit JSON. Logged 2026-03-22.

30. **Built-in letter preview (iPad)** — On macOS the rendered PDF opens in Preview.app, but iPad has no equivalent. When iOS compose is built, include a sheet/modal PDF viewer for rendered letters. PDFKit is cross-platform. Bundle with the iOS compose work. Logged 2026-03-22.

32. **Auto-update postcode lookup from ONS ONSPD** — Direct download works: `https://www.arcgis.com/sharing/rest/content/items/3080229224424c9cb53c0b48f5a64d27/data` (235MB zip, no auth). Item ID may change quarterly. Script exists at `scripts/generate_sector_lookup.py`. Could automate: download zip, unzip, run generator, commit. Quarterly is overkill — annually or per-release is fine. Postcodes don't move towns. Logged 2026-03-22.

29. **DOB field accepts any input** — Patient DOB field in AddressCard is a plain text field with no validation. Should enforce a date format (DD/MM/YYYY or date picker). Also relates to #14 (ISO 8601 standardisation). Logged 2026-03-22.

28. **Rename "Prime" to "Verified"** — "Prime" currently means both "primary/canonical" and "user has verified this address." "Verified" is clearer for the second meaning, which is how it's actually used. Affects: AddressCard UI, override schema (isPrime field), AddressRepository togglePrime(), extraction helpers. Logged 2026-03-22.

15. **Recipient tick boxes in AddressesView** — Each address card gets To/CC/None toggles so the user can override rules-based recipient defaults. Enables per-letter flexible recipient selection without a separate editor view. Deferred from Phase 3.5 — build after compose module is proven. Logged 2026-03-21.

14. **DOB stored as DD/MM/YYYY — should be ISO 8601** — `parsePatientFilename` outputs `DD/MM/YYYY` but page extraction uses ISO `YYYY-MM-DD`. Inconsistent internal format. ISO sorts correctly, enables range/prefix queries, and is unambiguous. Fix: change `parsePatientFilename` to output `YYYY-MM-DD`, rebuild entity DB. Post-migration improvement — don't change during consolidation. Logged 2026-03-21.

## Phase 3.1 Deduplication Notes (2026-03-21)

**Completed:** Deleted 4 Yiale duplicates (SharedWorkList, ClinicListParser, WorkListRepository, WorkListViewModel). All had Yiana equivalents that were equal or superset.

**Difference to carry forward:** Yiale's `WorkListViewModel` has `replaceClinicList()` (replace-all semantics, used in ContentView). Yiana only has `importClinicList()` (merge semantics). When porting compose views (Step 3.5), decide whether replace-all is needed or if merge is sufficient. The Yiale UX offered both "Import" (merge) and "Replace" buttons.

## Work List — reverted and redesigning (2026-03-08)

All work list code reverted from Yiana (commit cd5340a). Eight attempts to fix click navigation inside `List(selection:)` failed. The feature will be reimplemented from scratch with the work list OUTSIDE the sidebar List. Full spec and architectural constraint documented in `HANDOFF.md`. Diagnostic history in `docs/work-list-navigation-failures.md`.
