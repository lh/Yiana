# Yiale Feature Inventory

Phase 0.4 of the consolidation plan. Documents Yiale's features, data
contracts, and usage status for absorption into Yiana.

## Status: Active — used in production

Evidence:
- 2 draft letters in `.letters/drafts/`
- 4 rendered letter sets in `.letters/rendered/`
- Sender config present at `.letters/config/sender.json`
- Active work list with 3 items in `.worklist.json`

## App Overview

Yiale is a macOS-only letter composition app. It reads patient data
extracted by Yiana's backend, lets clinicians compose clinical letters,
submits them to Devon for Typst rendering, and displays the rendered
PDFs for printing.

**2,383 lines of Swift across 23 files.** No incomplete features, no TODOs,
no disabled code.

## Navigation Flow

```
ContentView (NavigationSplitView)
|
+-- Sidebar: DraftsListView
|   +-- Section: Clinic List (imported patient names + MRNs)
|   |   Selection -> PatientSearchView -> ComposeView
|   +-- Section: Drafts (saved letters)
|       Selection -> DraftDetailView (if rendered) or ComposeView (if editing)
|
+-- Detail: switches on sidebar selection
    +-- PatientSearchView: search all patients by name/DOB/MRN
    +-- ComposeView: letter form (patient, recipients, body)
    |   +-- AddressConfirmationSheet: final review before render
    +-- DraftDetailView: PDF viewer + print (macOS NSPrintOperation)
```

Toolbar: "New Letter" (Cmd+N), "Import Clinic List", "Clear Clinic List"

## Features — Used vs Speculative

| Feature | Status | Evidence |
|---------|--------|----------|
| Patient search (name/DOB/MRN) | Used | Core flow, always triggered |
| Clinic list import (paste text) | Used | 3 items in worklist |
| Letter composition (patient + recipients + body) | Used | 2 drafts exist |
| Recipient management (add/edit/delete, GP/specialist/patient) | Used | Drafts have recipients |
| Address confirmation before render | Used | Part of render flow |
| Render request to Devon | Used | 4 rendered outputs exist |
| PDF viewing (NSViewRepresentable + PDFKit) | Used | DraftDetailView |
| Print / Print All (NSPrintOperation) | Used | Core output mechanism |
| Dismiss rendered letter | Used | Cleanup flow |
| 5-second polling for render status | Used | DraftsViewModel timer |
| Implicit hospital_records recipient | Used | Auto-added to every draft |
| Sender config loading | Used | sender.json exists |
| Work list name matching (nameKey subset) | Used | Clinic list -> patient resolution |
| Three-tier data resolution (override > page > enriched) | Used | ResolvedPatient.init(from:) |

No speculative features found. Everything in the codebase is wired up and exercised.

## Data Contracts — What Yiale Reads

| Path | Format | Purpose | Owner |
|------|--------|---------|-------|
| `.addresses/*.json` | JSON (DocumentAddressFile) | Patient data for search/selection | Extraction service (Devon) |
| `.worklist.json` | JSON (SharedWorkList) | Clinic list items | Yiale writes, Yiana reads |
| `.letters/config/sender.json` | JSON (SenderConfig) | Letter sender identity | User-managed |
| `.letters/rendered/{letterId}/*.pdf` | PDF | Rendered letter output | Devon render service |

## Data Contracts — What Yiale Writes

| Path | Format | Purpose | Consumer |
|------|--------|---------|----------|
| `.letters/drafts/{letterId}.json` | JSON (LetterDraft) | Draft letters | Devon render service reads |
| `.worklist.json` | JSON (SharedWorkList) | Clinic list (import/clear) | Yiana reads for work list view |

## Data Contracts — What Yiale Does NOT Touch

- `.yianazip` documents (Yiana only)
- `.ocr_results/` (OCR service only)
- `.addresses/*.json` overrides (Yiana only)
- `.letters/inject/` (Yiana's InjectWatcher reads, Devon writes)

## JSON Schemas

### LetterDraft (`.letters/drafts/{letterId}.json`)

```json
{
  "letterId": "UUID string",
  "created": "ISO8601",
  "modified": "ISO8601",
  "status": "draft | renderRequested | rendered",
  "yianaTarget": "document_id (links to patient's .yianazip)",
  "patient": {
    "name": "string",
    "title": "Mr|Mrs|Ms|Miss|Dr|Prof",
    "dateOfBirth": "string or null",
    "mrn": "string or null",
    "address": ["line1", "line2", ...],
    "phones": ["number1", ...]
  },
  "recipients": [
    {
      "id": "UUID",
      "role": "gp | patient | specialist | hospital_records",
      "source": "extracted | manual | implicit",
      "name": "string",
      "practice": "string or null",
      "address": ["line1", "line2", ...]
    }
  ],
  "body": "letter text",
  "renderRequest": "ISO8601 or null"
}
```

### SenderConfig (`.letters/config/sender.json`)

```json
{
  "name": "Dr Full Name",
  "credentials": "MD, PhD",
  "role": "Consultant Specialty",
  "department": "Department Name",
  "hospital": "Hospital Name",
  "address": ["line1", "line2", ...],
  "phone": "number",
  "email": "email",
  "secretary": {
    "name": "Name",
    "phone": "number",
    "email": "email"
  }
}
```

### SharedWorkList (`.worklist.json`)

```json
{
  "modified": "ISO8601",
  "items": [
    {
      "id": "MRN or UUID",
      "mrn": "string or null",
      "surname": "string or null",
      "firstName": "string or null",
      "gender": "string or null",
      "age": "int or null",
      "doctor": "string or null",
      "resolvedFilename": "string or null",
      "source": "clinic_list | document | manual",
      "added": "ISO8601"
    }
  ]
}
```

## Code to Port (by priority)

### Must port (core letter flow)
1. **ComposeViewModel** (162 LOC) — letter composition state and save/render logic
2. **AddressData.swift ResolvedPatient** (~100 LOC of the 291) — three-tier resolution
3. **LetterDraft model** (92 LOC) — draft schema
4. **LetterRepository** (109 LOC) — draft file I/O
5. **RecipientEditor** (222 LOC) — recipient management UI
6. **ComposeView** (138 LOC) — letter form UI
7. **AddressConfirmationSheet** (89 LOC) — pre-render review
8. **DraftDetailView** (161 LOC) — PDF viewer + print (macOS only)

### Port if work list stays
9. **SharedWorkList** (44 LOC) — already duplicated in Yiana (delete one copy)
10. **WorkListViewModel** (65 LOC) — clinic list state
11. **ClinicListParser** (59 LOC) — paste import
12. **ClinicListImportSheet** (88 LOC) — import dialog

### Eliminated by consolidation
13. **AddressSearchService** (95 LOC) — Yiana already has AddressRepository
14. **ICloudContainer** (55 LOC) — Yiana already has iCloud path management
15. **SenderConfigService** (19 LOC) — trivial, merge into existing service layer
16. **PatientSearchView** (210 LOC) — replace with Yiana's existing patient/address views
17. **DraftsListView** (103 LOC) — integrate into Yiana's sidebar
18. **DraftRow** (68 LOC) — merge into Yiana's list item style

### Net new code estimate
- Port ~900 LOC (compose flow + recipient editor + draft detail)
- Delete ~500 LOC (duplicated services, separate app scaffold)
- Eliminate SharedWorkList.swift duplication (1442 LOC saved in Yiale, keep Yiana's copy)

## Screenshots

Removed — original captures contained real patient data. To recapture:
create a test draft with synthetic patient data in Yiale, then screenshot.

Screens needed:
- [ ] Sidebar with drafts list + patient search
- [ ] Compose form with recipients
- [ ] Rendered PDF viewer with print controls
