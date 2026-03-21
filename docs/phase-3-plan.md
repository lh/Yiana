# Phase 3: Letter Composition (Yiale Absorption)

> **Created:** 2026-03-21
> **Status:** Planning
> **Branch:** `consolidation/v1.1`

---

## Goal

Absorb Yiale's letter composition features into Yiana as a "Compose" module. After this phase, Yiale is retired and all letter composition happens inside Yiana.

## Why

Yiale was originally a separate app so users could view notes in Yiana while composing letters side-by-side. In practice, maintaining two apps that share an iCloud container creates duplication (SharedWorkList, AddressSearchService, WorkListRepository, ICloudContainer) and deployment friction. With the entity database now in Yiana, patient search can be faster and richer than Yiale's file-based approach.

The compose module becomes a tab or navigation destination within Yiana, not a separate app. On macOS, users can still use a separate window if needed (Window > New Window). On iPad, the compose view sits within Yiana's navigation structure.

## Scope

- Port all Yiale views, models, services into Yiana
- Replace file-based patient search with entity database queries
- Eliminate SharedWorkList duplication
- Preserve all existing iCloud file formats (`.letters/drafts/`, `.letters/rendered/`)
- The render service on Devon is unchanged (it watches the same iCloud paths)
- InjectWatcher is already in Yiana (172 lines, working)

## What is NOT changing

- Draft JSON schema (frozen per migration rules)
- `.letters/` directory structure
- Render service on Devon
- InjectWatcher in Yiana
- The clinical letter structure (patient-addressed, cc'd to all recipients)

---

## Inventory: What Yiale Has (24 files, ~2400 LOC)

### Models (5 files)
| File | Lines | Port strategy |
|------|-------|--------------|
| `LetterDraft.swift` | 92 | Copy to `Yiana/Models/` — no changes needed |
| `AddressData.swift` | 291 | Replace with entity DB queries — most of this becomes unnecessary |
| `SharedWorkList.swift` | 44 | Delete — already exists in Yiana |
| `SenderConfig.swift` | ~40 | Copy to `Yiana/Models/` |
| `WorkListEntry.swift` | ~30 | Already exists in Yiana |

### Services (6 files)
| File | Lines | Port strategy |
|------|-------|--------------|
| `LetterRepository.swift` | 109 | Copy to `Yiana/Services/` — adapt iCloud URL source |
| `AddressSearchService.swift` | 109 | Replace with EntityDatabaseService queries |
| `SenderConfigService.swift` | ~60 | Copy to `Yiana/Services/` — adapt iCloud URL source |
| `WorkListRepository.swift` | 58 | Delete — already exists in Yiana (155 lines, more complete) |
| `ClinicListParser.swift` | 60 | Already exists in Yiana |
| `ICloudContainer.swift` | ~80 | Delete — Yiana already caches iCloud URL in each service |

### Views (9 files)
| File | Lines | Port strategy |
|------|-------|--------------|
| `ComposeView.swift` | 138 | Port to `Yiana/Views/Compose/` |
| `PatientSearchView.swift` | 210 | Port — rewire to entity DB |
| `RecipientEditor.swift` | 222 | Port to `Yiana/Views/Compose/` |
| `DraftDetailView.swift` | 161 | Port — macOS-only (`#if os(macOS)` for NSPrintOperation) |
| `DraftsListView.swift` | 100 | Port to `Yiana/Views/Compose/` |
| `AddressConfirmationSheet.swift` | 89 | Port to `Yiana/Views/Compose/` |
| `ClinicListImportSheet.swift` | 88 | Port to `Yiana/Views/Compose/` |
| `DraftRow.swift` | 40 | Port to `Yiana/Views/Compose/` |
| `StatusBadge.swift` (in DraftRow) | 24 | Port inline |

### ViewModels (3 files)
| File | Lines | Port strategy |
|------|-------|--------------|
| `ComposeViewModel.swift` | 163 | Port — adapt patient selection to entity DB |
| `DraftsViewModel.swift` | 60 | Port to `Yiana/ViewModels/` |
| `WorkListViewModel.swift` | 66 | Delete — already exists in Yiana |

---

## Implementation Steps

### 3.1 Preparation and deduplication

- [x] Delete `Yiale/Yiale/Models/SharedWorkList.swift` (duplicate of Yiana's) — identical
- [x] Verify Yiana's `ClinicListParser.swift` matches Yiale's (delete Yiale's if identical) — functionally identical
- [x] Verify Yiana's `WorkListRepository.swift` is a superset of Yiale's (delete Yiale's) — superset (singleton, cached URLs, legacy migration, mergeAndSave)
- [x] Verify Yiana's `WorkListViewModel.swift` is a superset of Yiale's (delete Yiale's) — superset (325 vs 66 lines)
- [x] Document any differences found — Yiale has `replaceClinicList()` (replace-all semantics); Yiana only has merge. Logged to Serena memory; decide at Step 3.5

**Test gate:** PASSED — both iOS and macOS build. All deleted code has Yiana equivalents.

### 3.2 Port models

- [x] Copy `LetterDraft.swift` to `Yiana/Yiana/Models/` — includes LetterStatus, LetterPatient, LetterRecipient, LetterDraft
- [x] Copy `SenderConfig.swift` to `Yiana/Yiana/Models/` — includes Secretary, SenderConfig
- [x] Do NOT port `AddressData.swift` — the `ResolvedPatient` pattern will be replaced by entity DB queries
- [x] Build both platforms

**Test gate:** PASSED — iOS and macOS build. No new functionality yet.

### 3.3 Port services

- [x] Copy `LetterRepository.swift` to `Yiana/Yiana/Services/` — singleton with cached iCloud URL, replaced ICloudContainer.shared with per-service caching
- [x] Copy `SenderConfigService.swift` to `Yiana/Yiana/Services/` — same pattern, returns nil instead of throwing when iCloud unavailable
- [x] Both services compute draftsURL, renderedURL, configURL from cached container URL
- [x] Build both platforms

**Test gate:** PASSED — iOS and macOS build. Services compile but are not yet called.

### 3.4 Port patient search (entity DB migration)

This is the key improvement over Yiale. Instead of loading every `.addresses/*.json` file and doing in-memory search, we query the entity database.

- [x] Add search methods to `EntityDatabase`: `searchPatients(query:limit:)` and `searchPractitioners(query:limit:)` — LIKE on normalized name, DOB, or practice name; ordered by document_count DESC
- [x] Add wrapper methods to `EntityDatabaseService`
- [x] Write 12 tests: empty query, whitespace, partial name, case-insensitive, DOB match (DD/MM/YYYY format), no match, ordered by doc count, limit, practitioner by name, practitioner by practice
- [x] Build both platforms and run package tests (94/94 pass)

**Test gate:** PASSED — patient/practitioner search returns correct results. All 94 tests pass. Both platforms build.

### 3.5 Port compose views

**Redesigned:** Instead of porting 9 Yiale views, built a simplified compose module:
- Recipients are rules-based (patient=To, GP=CC), no manual editor
- Body is a text blob (markdown/plain text), no greeting/salutation
- Compose is a tab in DocumentInfoPanel, replacing the addresses view when active
- Drafts list deferred

- [x] Create `Yiana/Yiana/Views/Compose/` directory
- [x] Create `ComposeTab.swift` — text area + status + save/send/print buttons (macOS, ~125 lines)
- [x] Create `ComposeViewModel.swift` — load/save/send via LetterRepository, auto-fill from prime addresses (~175 lines)
- [x] Add "Compose" tab to `DocumentInfoPanel.swift`
- [x] Build both platforms
- [ ] PatientSearchView — NOT ported (patient from document context)
- [ ] RecipientEditor — NOT ported (rules-based)
- [ ] AddressConfirmationSheet — NOT ported (auto-filled)
- [ ] DraftsListView, DraftRow — deferred
- [ ] DraftDetailView — PDF viewing inline in compose tab

**Test gate:** PASSED — iOS and macOS build. Compose tab appears in info panel.

### 3.6 Port view models

**Redesigned:** Simplified ComposeViewModel built from scratch instead of porting Yiale's.
- [x] `ComposeViewModel.swift` (~175 lines) — auto-fills from prime addresses, saves/sends via LetterRepository
- [ ] `DraftsViewModel.swift` — deferred (no drafts list yet)
- [x] Build both platforms

**Test gate:** PASSED — iOS and macOS build.

### 3.7 Wire into Yiana navigation

**Redesigned:** Compose is a tab in DocumentInfoPanel, not a separate navigation destination.
- [x] Compose tab added to DocumentInfoPanel (macOS)
- [ ] iOS compose access — deferred (info panel is macOS-only currently)
- [x] Build both platforms

**Test gate:** PASSED — iOS and macOS build. Compose tab in info panel.

### 3.8 Integration testing

- [ ] Create a test draft via compose UI, verify JSON written to `.letters/drafts/`
- [ ] Verify draft appears in drafts list
- [ ] Verify "Send to Print" writes `render_requested` status
- [ ] Verify rendered PDFs appear (requires Devon render service running)
- [ ] Verify InjectWatcher appends hospital records PDF to patient document
- [ ] Verify clinic list import works (paste -> parse -> resolve to patients)
- [ ] Test on both iOS and macOS

**Test gate:** Full compose-to-render-to-inject flow works on both platforms.

### 3.9 Retire Yiale

- [ ] Confirm all Yiale features work in Yiana (acceptance criteria from 3.1)
- [ ] Remove Yiale from App Store Connect (if published)
- [ ] Archive `Yiale/` directory (git preserves history)
- [ ] Remove Yiale.xcodeproj from workspace (if in shared workspace)
- [ ] Update CLAUDE.md to remove Yiale references
- [ ] Update LETTER-MODULE-SPEC.md to reflect compose module is now in Yiana

**Test gate:** Yiale directory archived. iOS and macOS build. All compose features verified.

---

## Design Decisions (Resolved 2026-03-21)

1. **Navigation pattern** — The compose view must NOT obscure the underlying
   Yiana document. The user reads scanned notes while composing, often pasting
   text from the notes into the letter. On macOS: a panel, inspector, or
   non-modal presentation that sits alongside the document. On iPad: split view
   or slide-over. This will need iteration — don't commit to the first design.

2. **Document context integration** — YES. Compose is initiated from the
   document's address data. Patient, GP, and specialists are auto-filled from
   the document context. The user writes body text only — topping and tailing
   (addresses, salutation, cc lines, "Re:" line) happens behind the scenes.
   Recipient details are shown at a confirmation step, not during editing.

3. **iOS DraftDetailView** — Simple as possible. Share sheet or basic PDFView
   for rendered PDFs. No NSPrintOperation equivalent needed on iOS.

4. **Work list vs drafts** — These are separate concepts. Work list = notes
   to see today (drives the clinical session). Drafts = letters being composed
   (tracks letter status). Both need to exist as separate views. A work list
   entry can have a "compose letter" action, but the lists are distinct.

5. **Rendering** — LaTeX on Devon, unchanged. The user values the typography
   (microkerning etc). The compose module writes draft JSON with body text.
   Rendering is Devon's job. The app shows the rendered PDF when it comes back.
   Body text could be written in markup and piped to whatever renderer.

---

## Estimated Effort

| Step | New LOC | Eliminated LOC | Notes |
|------|---------|---------------|-------|
| 3.1 Deduplication | 0 | ~200 | Delete Yiale duplicates |
| 3.2 Models | ~130 | 0 | LetterDraft + SenderConfig |
| 3.3 Services | ~170 | 0 | LetterRepository + SenderConfigService |
| 3.4 Patient search | ~80 | 0 | Entity DB search methods + tests |
| 3.5 Views | ~800 | 0 | 9 view files ported and adapted |
| 3.6 View models | ~200 | 0 | ComposeViewModel + DraftsViewModel adapted |
| 3.7 Navigation | ~50 | 0 | Entry point wiring |
| 3.8 Testing | 0 | 0 | Manual verification |
| 3.9 Retirement | 0 | ~2400 | Archive Yiale |
| **Total** | **~1430** | **~2600** | Net reduction of ~1170 lines |

---

## Dependencies

- **Entity database** (Phase 2) — DONE. Patient/practitioner search is the foundation.
- **Render service on Devon** — unchanged, watches `.letters/drafts/` via iCloud
- **InjectWatcher in Yiana** — already working (172 lines)
- **iCloud file formats** — frozen per migration rules

## Risks

- **iCloud sync latency** — drafts written on iOS may take seconds to appear on Devon for rendering. This is the existing behaviour from Yiale; no change.
- **AddressData.swift replacement** — Yiale's `ResolvedPatient` does override/enrichment resolution that the entity DB already handles differently. Need to verify the compose view gets equivalent data.
- **Work list integration** — merging Yiale's drafts list with Yiana's work list may surface UX decisions about how these relate.
