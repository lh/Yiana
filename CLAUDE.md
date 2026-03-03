# CLAUDE.md

## Core Rules

1. **Use Serena MCP tools for code exploration and editing** — `get_symbols_overview`, `find_symbol`, `search_for_pattern`, `replace_symbol_body`, `insert_before_symbol`/`insert_after_symbol`. Fall back to Read/Edit only for non-code files or tiny edits. If `find_symbol` fails, switch to `search_for_pattern` immediately — do not retry.
2. **Build for BOTH iOS and macOS after any code change.** Use the `/check` skill or the xcode-mcp-server. Never assume shared code only affects one platform.
3. **Clean desk.** Run `git status` before starting any new task. Address uncommitted changes first. A SessionStart hook reminds you, but do not rely on it alone.
4. **Log ideas and problems** to Serena memory `ideas_and_problems` using `edit_memory`. Do not use Vestige for this.

## Session Protocol

- **Start:** Read `HANDOFF.md` if it exists. Run `git status`.
- **End:** Write a detailed handoff to `HANDOFF.md` — what was completed, what's in progress, what's next, known issues.

## Project Overview

Yiana is a document scanning and PDF management app for iOS/iPadOS/macOS. It stores documents as `.yianazip` packages (ZIP archives containing `metadata.json`, `content.pdf`, `format.json`), syncs via iCloud Drive, and processes OCR both on-device and via a Mac mini backend.

Primary languages: **Swift** (app) and **Python** (server services).

## Architecture

### Document Storage
- **UIDocument** (iOS/iPadOS) and **NSDocument** (macOS) — NOT Core Data
- iCloud container: `iCloud.com.vitygas.Yiana`
- Package format: `.yianazip` via `YianaDocumentArchive` (ZIPFoundation)
- Bundle ID: `com.vitygas.Yiana`
- Each platform uses native document classes directly — no shared protocols

### PDF Handling
- **PDFKit** for read-only viewing (no annotations)
- **1-based page indexing everywhere** — convert only at PDFKit API boundaries
- Wrapper extensions in `Extensions/PDFDocument+PageIndexing.swift`

### OCR Processing
- **On-device:** `OnDeviceOCRService` uses Vision framework
- **Server:** `YianaOCRService` (Mac mini) watches for `ocrCompleted = false`; results in `.ocr_results/` as JSON/XML/hOCR
- Metadata tracks source via `ocrSource` enum: `.onDevice`, `.service`, `.embedded`

### Address Extraction
- Extraction service on Devon watches `.ocr_results/`, writes to `.addresses/{document_id}.json`
- Three-tier data resolution: **override > extraction > enrichment**
- `pages[]` owned by Devon, `overrides[]` owned by Swift app, `enriched{}` written back by backend DB
- Backend database (`backend_db.py`) deduplicates patients and practitioners across documents

### Server (Mac mini "Devon")
- IP: `192.168.1.137`, user: `devon`, Tailscale: `devon-6`
- **OCR service:** LaunchDaemon at `/Library/LaunchDaemons/com.vitygas.yiana-ocr.plist` (Swift binary, `sudo` required)
- **Extraction service:** LaunchAgent at `~/Library/LaunchAgents/com.vitygas.yiana-extraction.plist` (Python 3.12)
- **Dashboard:** LaunchAgent at `~/Library/LaunchAgents/com.vitygas.yiana-dashboard.plist` (typst-live on port 5599)
- **Watchdog:** cron every 5min, Pushover alerts
- Log rotation: `/etc/newsyslog.d/` configs (10MB, 3 copies, bzip2)

### Deployment
Use the `/deploy` skill. Protocol: stop launchd service FIRST → wait for confirmation → copy binary → start service → verify. Never deploy without explicit user confirmation. Check log file sizes before verification.

## Build & Test

```bash
# Build both platforms (preferred: use /check skill or xcode-mcp-server)
xcodebuild -scheme Yiana -destination 'generic/platform=iOS'
xcodebuild -scheme Yiana -destination 'platform=macOS'

# Build OCR service
cd YianaOCRService && swift build

# Run OCR service
cd YianaOCRService && swift run yiana-ocr --help
```

## Repository Structure

```
Yiana/                      # SwiftUI app (iOS/iPadOS/macOS)
├── Models/                # DocumentMetadata, NoteDocument, ExtractedAddress
├── ViewModels/            # DocumentListViewModel, DocumentViewModel
├── Views/                 # SwiftUI views (DocumentListView, PDFViewer, AddressesView, etc.)
├── Services/              # DocumentRepository, ImportService, SearchIndexService, AddressRepository
├── Extensions/            # PDFDocument+PageIndexing, other wrappers
├── Accessibility/         # VoiceOver support
├── Markup/                # PDF markup code
└── Utilities/             # Helper functions

YianaDocumentArchive/      # Swift Package for .yianazip format (ZIPFoundation)
YianaOCRService/           # Swift Package executable for server-side OCR
AddressExtractor/          # Python: extraction service, backend DB, letter generation (legacy)
scripts/                   # Dashboard, watchdog, status, deployment scripts
docs/                      # Technical documentation, specs
```

## Custom Skills

- `/deploy` — Deploy OCR service binary to Devon
- `/check` — Build both iOS and macOS targets, report pass/fail
- `/testflight` — Bump build number, archive, upload to App Store Connect

## Hooks

- `postToolUse` on `TaskUpdate` — auto-builds both platforms when a task is marked completed

## Code Style

### Page Numbering (CRITICAL)
- Always 1-based in UI, metadata, OCR JSON, search results
- Use `pdfDocument.getPage(number: 1)` not `pdfDocument.page(at: 0)`

### Platform-Specific Code
```swift
#if os(iOS)
    // iOS-specific
#elseif os(macOS)
    // macOS-specific
#endif
```

### Async State Capture (CRITICAL)
Never read `@State` or `@Published` inside `Task {}` bodies — capture to a local first:
```swift
let captured = someState
someState = nil
Task { doSomething(with: captured) }
```

### `.task {}` and File I/O (CRITICAL)
SwiftUI `.task {}` inherits the main actor. Wrap file I/O in `Task.detached { ... }.value`. Extract `@MainActor` methods to free functions if needed for `@Sendable` compliance.

### List Selection vs NavigationLink
`List(selection:)` is silently broken when rows contain `NavigationLink` or `Button`. Conditionally render plain content in select mode, NavigationLink in normal mode.

### iOS List Rows Cannot Be Drop Targets
`.onDrop` on individual rows inside an iOS `List` does not work (UITableView intercepts). Use `ScrollView` + `LazyVStack` for drop targets. macOS `List` is fine.

## Dependency Management

### Approved
- **GRDB.swift** (v7.7+) — Type-safe SQLite wrapper

### Adding Dependencies
Only when: complex subsystem, 10x time savings, 5+ years maturity, safety-critical.
Not for: <50 lines of code, Apple framework duplicates, unmaintained projects, heavy frameworks used at 10%.

## Design Principles

1. Use proven Apple frameworks — don't reimplement what the platform provides
2. Simplicity over feature bloat
3. Read-only PDF viewing (no annotations)
4. Mac mini handles heavy processing (OCR, extraction, rendering)
5. iCloud as the sync and sharing layer

