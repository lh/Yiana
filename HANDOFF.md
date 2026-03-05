# Session Handoff — 2026-03-05

## What was completed

### Yiale Mac app — full letter composition UI

Created a new SwiftUI macOS app (`Yiale/Yiale.xcodeproj`, bundle ID `com.vitygas.Yiale`, macOS 14.0+) for composing clinic letters. Builds with zero errors, zero warnings.

**Project structure:**
```
Yiale/
├── Yiale.xcodeproj/
└── Yiale/
    ├── YialeApp.swift              # App entry, ICloudContainer.setup() in .task {}
    ├── ContentView.swift           # NavigationSplitView root, iCloud availability check
    ├── Yiale.entitlements          # iCloud container iCloud.com.vitygas.Yiana (CloudDocuments)
    ├── Models/
    │   ├── LetterDraft.swift       # LetterDraft, LetterPatient, LetterRecipient, LetterStatus
    │   ├── SenderConfig.swift      # SenderConfig, Secretary
    │   └── AddressData.swift       # Codable structs from ExtractedAddress.swift + ResolvedPatient
    ├── Services/
    │   ├── ICloudContainer.swift   # Cached ubiquity container URL singleton
    │   ├── AddressSearchService.swift  # Load .addresses/, resolve overrides, search
    │   ├── LetterRepository.swift  # CRUD for .letters/drafts/*.json, atomic writes
    │   └── SenderConfigService.swift   # Read .letters/config/sender.json
    ├── ViewModels/
    │   ├── ComposeViewModel.swift  # Compose flow: patient selection, recipients, save/render
    │   └── DraftsViewModel.swift   # Drafts list with polling
    └── Views/
        ├── PatientSearchView.swift # Search field + results (name/DOB/MRN/GP)
        ├── ComposeView.swift       # Patient info, recipients, body editor
        ├── RecipientEditor.swift   # Add/remove recipients with role badges
        ├── AddressConfirmationSheet.swift  # Confirm addresses + yiana_target before render
        ├── DraftsListView.swift    # Sidebar with status badges
        ├── DraftRow.swift          # Draft row with patient name, MRN, status, date
        └── DraftDetailView.swift   # PDF preview of rendered output, dismiss button
```

**Key implementation details:**
- JSON output matches `letter_models.py` exactly (snake_case keys via CodingKeys)
- Override resolution replicates `AddressRepository.resolveAddresses()` logic
- MRN parsed from documentId filename convention (last underscore-separated component)
- Hospital_records recipient added implicitly (not shown in UI, always included)
- GP auto-populated from resolved patient data
- iCloud patterns: cached container URL, `options: []` for directory listings, `Task.detached` for file I/O
- Atomic file writes: encode → temp file → `FileManager.replaceItemAt()`
- Drafts list polls every 5 seconds for status changes
- DraftDetailView uses PDFKit for rendered output preview
- Keyboard shortcuts: Cmd+N (new letter), Cmd+S (save draft)
- Error handling: iCloud unavailable overlay, compose error alerts

### Previous session work (carried forward)
- Inject watcher — Phase 3 (`c4b7fd1`)
- Render service deployed to Devon with LaunchAgent
- End-to-end pipeline verified (draft → render → inject → append)
- Yiale render service — Phases 1+2 (`2d712f8`)

## What's in progress
- Nothing actively in progress — Yiale app is not yet committed

## What's next
- **End-to-end test**: Run the app, search a real patient, compose, render, verify Devon processes it
- **Yiale iOS/iPadOS** — adapt SwiftUI views for smaller screens
- **Cleanup** — archive superseded components (`letter_generator.py`, `letter_cli.py`, `letter_system_db.py`, `clinic_notes_parser.py`)

## Known issues
- iCloud `[ERROR] [Progress]` noise when InjectWatcher renames/deletes `.processing` file — harmless
- Transient "database is locked" on reindex after inject append — resolves on next UbiquityMonitor cycle
- Stale Mercy-Duffy error in OCR health (21+ days old) — not actionable
- `ocr_today` dashboard count shows 0 — may be timezone issue
- Old `ocr_watchdog_pushover.sh` still in `YianaOCRService/scripts/` — can remove after confirming unified watchdog
- `letter_generator.py:_escape_latex()` brace-corruption bug — low priority, being superseded

## Devon services status
| Service | Type | Status |
|---|---|---|
| `com.vitygas.yiana-ocr` | LaunchDaemon | Running |
| `com.vitygas.yiana-extraction` | LaunchAgent | Running |
| `com.vitygas.yiana-dashboard` | LaunchAgent | Running |
| `com.vitygas.yiana-render` | LaunchAgent | Running |
