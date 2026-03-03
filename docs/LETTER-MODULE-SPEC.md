# Yiale — Letter Composition Module for Yiana

> **Date:** 3 March 2026
> **Status:** Draft v4
> **Scope:** Letter composition, rendering, and delivery for Yiana ecosystem

---

## 1. Overview

Yiale is a standalone SwiftUI app for composing clinical correspondence. It runs on macOS, iOS, and iPadOS. It is a companion to Yiana, not part of it.

Yiale and Yiana share the same iCloud container. Both apps list the same iCloud container identifier in their entitlements; Apple permits this for apps from the same developer team. No App Group is needed for the iCloud layer.

Yiale is a separate app because it serves a separate task. In practice, the user reads patient notes in Yiana while composing a letter in Yiale, side by side. On macOS this means two windows; on iPad it means Split View with two apps.

The system has three parts:

- **Yiale** — SwiftUI app for composing letters on any device
- **Render Service** — Mac Mini watcher that converts drafts to PDF via LaTeX and HTML
- **Yiana Inject Watcher** — a small addition to Yiana that auto-appends rendered PDFs to patient documents using Yiana's existing append logic

**Letter structure principle.** In UK clinical correspondence, the letter is addressed to the patient. The GP, optician, specialist, and hospital records each receive an identical copy. Copies differ only in postal address (for the envelope window) and font size (patient copy is 14pt with wider line spacing; all others are 11pt). Each copy includes a "Re:" line (patient name, DOB, MRN) between the address block and the salutation. Each copy lists all other recipients on its cc line.

**Correcting a rendered letter.** Once a letter is rendered and appended to a patient's Yiana document, it cannot be retracted. Removing pages from a Yiana document is a destructive operation. If a rendered letter contains an error, compose a new corrected letter. The old letter remains in the patient record. This is standard clinical practice; a corrected letter is a new letter, not an edit to an old one.

Yiana is otherwise unchanged. Other Yiana users are unaffected.

---

## 2. Directory Structure

All paths are relative to the shared iCloud container root.

```
SharedContainer/
├── .addresses/          ← existing; read by Yiale
│   └── {document_id}.json
├── .ocr_results/        ← existing; untouched
├── .letters/            ← NEW; owned by Yiale + render service
│   ├── drafts/
│   │   └── {letter_id}.json
│   ├── rendered/
│   │   └── {letter_id}/
│   │       ├── Smith_Jane_120345_to_Dr_Patel.pdf
│   │       ├── Smith_Jane_120345_patient_copy.pdf
│   │       ├── Smith_Jane_120345_hospital_records.pdf
│   │       └── Smith_Jane_120345_email.html
│   ├── inject/
│   │   └── {yiana_target}_{letter_id}.pdf
│   ├── unmatched/
│   │   └── (PDFs where yiana_target was not found)
│   └── config/
│       └── sender.json
├── documents/           ← existing; Yiana document store
│   └── ...
```

### Notes

- `.letters/` is invisible to Yiana except for the `inject/` subdirectory.
- `drafts/` is written by Yiale on any device. Read by the Mac Mini render service.
- `rendered/` is written by the Mac Mini. Read by Yiale for preview, share sheet, and dismissal.
- `inject/` is the handoff point between the render service and Yiana. The render service places the hospital records PDF here, named `{yiana_target}_{letter_id}.pdf`. Yiana's inject watcher picks it up, appends it to the target document, and deletes the file. If the target document is not found, the file is moved to `unmatched/`.
- `unmatched/` holds PDFs where no matching Yiana document was found. The user appends these manually via Yiana's share sheet.
- `config/sender.json` holds the consultant's own details. Edited once; synced everywhere.
- Printable PDFs live in `.letters/rendered/` in iCloud. This is the canonical output location. Any further copying (e.g. to a shared Dropbox folder) is a personal deployment choice, not part of Yiale's design. See Appendix A.

---

## 3. Draft JSON Schema

Each letter draft is a single JSON file in `.letters/drafts/`.

```json
{
  "letter_id": "uuid-v4",
  "created": "2026-03-03T14:30:00Z",
  "modified": "2026-03-03T14:35:00Z",
  "status": "draft",

  "yiana_target": "Smith_Jane_120345",

  "patient": {
    "name": "Mrs Jane Smith",
    "dob": "1945-03-12",
    "mrn": "H123456",
    "address": ["14 Oak Lane", "Reigate", "Surrey", "RH2 7AA"],
    "phones": ["01737 123456"]
  },

  "recipients": [
    {
      "role": "patient",
      "source": "database",
      "name": "Mrs Jane Smith",
      "address": ["14 Oak Lane", "Reigate", "Surrey", "RH2 7AA"]
    },
    {
      "role": "gp",
      "source": "database",
      "name": "Dr A Patel",
      "practice": "Reigate Medical Centre",
      "address": ["12 High Street", "Reigate", "Surrey", "RH2 9AE"]
    },
    {
      "role": "optician",
      "source": "ad_hoc",
      "name": "Mr B Jones",
      "practice": "Reigate Opticians",
      "address": ["5 Bell Street", "Reigate", "Surrey", "RH2 7AB"]
    },
    {
      "role": "hospital_records",
      "source": "implicit",
      "name": "Hospital Records",
      "address": []
    }
  ],

  "body": "Thank you for referring this patient who I saw in clinic today.\n\nShe reports gradual deterioration of vision in the right eye over six months...",

  "render_request": null
}
```

### Field notes

| Field | Description |
|-------|-------------|
| `letter_id` | UUID generated by Yiale at creation. |
| `status` | `draft` → `render_requested` → `rendered` → user dismisses → deleted. |
| `yiana_target` | Confirmed Yiana document filename to append the letter to. Pre-populated from the address data's `document_id` field; shown to user during address confirmation; editable. This is the only link between the letter and the Yiana document. |
| `recipients[]` | All postal destinations including patient and hospital records. The cc line on each printed copy is derived from this list: all recipients except the current one. Font size is not stored; the render service applies the rule: `role == "patient"` → 14pt, all others → 11pt. Hospital records has an empty address array; the render service omits the postal address block for this copy. |
| `body` | Plain text. Paragraphs separated by blank lines. Bullet lists supported (`- item`). No other formatting. |
| `render_request` | Set to a timestamp by Yiale when the user confirms addresses and taps "Send to print". The Mac Mini watches for this. |

### Status transitions

```
draft → render_requested     (user confirms addresses and taps "Send to print")
render_requested → rendered  (Mac Mini completes PDFs + HTML)
rendered → [user dismisses]  (user sees "rendered" badge, reviews, taps to dismiss)
[dismissed] → draft JSON deleted
```

The draft JSON is retained after rendering so the drafts list can show a "rendered" status badge. The user dismisses the entry once they are satisfied the PDFs are correct. This is the acknowledgment step. After dismissal, the JSON is deleted. The PDFs in `.letters/rendered/` and in Yiana are the canonical records.

There is no path from `rendered` back to `draft`. If the user spots an error in preview, they compose a new letter. The rendered PDFs and the appended Yiana pages are not retracted. See §1 (Correcting a rendered letter).

---

## 4. Sender Configuration

`.letters/config/sender.json` — set once, synced to all devices.

```json
{
  "name": "Mr L Arblaster",
  "credentials": "FRCOphth",
  "role": "Consultant Ophthalmologist",
  "department": "Ophthalmology Department",
  "hospital": "East Surrey Hospital",
  "address": ["Canada Avenue", "Redhill", "Surrey", "RH1 5RH"],
  "phone": "01737 768511",
  "email": "l.arblaster@nhs.net",
  "secretary": {
    "name": "Mrs J Davies",
    "phone": "01737 768511 ext 1234",
    "email": "j.davies@nhs.net"
  }
}
```

These are placeholder values. Replace with real details.

---

## 5. Yiale (SwiftUI App)

### 5.1 Platforms and container sharing

macOS, iOS, iPadOS. Single SwiftUI codebase. Minimal UI.

Yiale and Yiana share the same iCloud container by listing the same iCloud container identifier in their entitlements. Apple permits this for apps from the same developer team. No App Group is required for the iCloud layer.

### 5.2 Screens

**Patient Search.** A single search field. Searches `.addresses/` files by patient name, DOB, or MRN. Results show patient name, DOB, and linked GP. Tap to select.

**Compose.** Shows:

- Patient name, address, DOB, MRN (read from addresses; not editable here; edit in Yiana)
- GP name and address (auto-populated from database link)
- Additional copy recipients (add via search or manual entry; e.g. optician, specialist)
- Body text field (large, plain text, paste-friendly)
- "Send to print" button

The letter is always addressed to the patient. Recipients receive identical copies posted to their own addresses. The patient and hospital records entries are added to `recipients[]` automatically by Yiale.

**Address confirmation.** Triggered by "Send to print". A modal or sheet showing:

- Patient name and address (postal destination for patient copy)
- Each copy recipient's name and postal address
- Yiana target document: `Smith_Jane_120345` (pre-populated; editable)

The user must explicitly confirm before the draft moves to `render_requested`. This is the last gate before the Mac Mini picks it up.

**Drafts list.** All letters in `.letters/drafts/`, sorted by modification date. Status badge shows draft / rendering / rendered. Once rendered, the user can preview the PDF, share the HTML via share sheet, or dismiss the entry (which deletes the draft JSON).

**Preview.** Once rendered, shows the PDF inline (on Mac) or allows sharing the HTML version (on iOS/iPad for email via share sheet).

### 5.3 Ad-hoc recipients

The user can add a recipient not in the database by tapping "Add recipient" and filling in name, role, and address manually. These are stored in the draft JSON with `"source": "ad_hoc"`. They are not written back to the address database directly. However, when the letter is appended to the patient's Yiana document and OCR processes it, the addresses are extracted and enter the database naturally.

### 5.4 Body text input

The body field accepts plain text. The user can paste from Apple Notes, a text file, or type directly.

Supported formatting:

- Paragraphs (blank line separated)
- Bullet lists (`- item`)

That is all. Clinical letters are prose paragraphs with an occasional bullet list for diagnoses or management plans. The render service converts `- ` prefixed lines to LaTeX `\begin{itemize}` environments; everything else is paragraphs. No markdown library required.

---

## 6. Render Service (Mac Mini)

### 6.1 Watcher

A Python script (or launchd job) that watches `.letters/drafts/` for JSON files where `render_request` is non-null and `status` is `render_requested`.

Poll interval: 30 seconds. FSEvents can be used for faster pickup later; polling is fine as a starting point.

**Latency note.** The full round trip is: Yiale writes draft JSON → iCloud syncs to Mac Mini → render service picks it up → writes PDFs → iCloud syncs back. That is two iCloud sync hops. On a local network, expect 30 seconds to 2 minutes. On different networks, up to 3 minutes. This is acceptable; the user composes letters during or after clinic and the secretary prints later. Yiale shows "Sent for rendering" immediately and updates to "Rendered" when the PDFs appear in `.letters/rendered/`.

### 6.2 Rendering pipeline

All copies of a letter are identical in content. The letter is addressed to the patient (salutation, body, sign-off). Each copy includes a "Re:" line: `Re: Mrs Jane Smith, DOB 12/03/1945, MRN H123456`. Copies differ only in:

- **Postal address** (the envelope/window address block): patient's home, GP surgery, etc. The hospital records copy omits the postal address block entirely. It is filed, not posted.
- **Font size**: the render service applies the rule `role == "patient"` → 14pt body with 1.4× line spacing; all others → 11pt standard. No font size field in the JSON.
- **CC line**: derived from `recipients[]`; lists all recipients other than the current one.

For each draft to render:

1. Read the draft JSON and `sender.json`.
2. Render the letter body once (it is the same for all recipients).
3. For each entry in `recipients[]`: generate a PDF with that recipient's postal address in the window position (or no address block for hospital records), the appropriate font size, and a cc line listing all other recipients.
4. Generate an HTML version for emailing (no fixed font size; relative sizing).
5. Write all PDFs and HTML to `.letters/rendered/{letter_id}/`.
6. Place the hospital records PDF in `.letters/inject/{yiana_target}_{letter_id}.pdf` for Yiana's inject watcher to pick up.
7. Update the draft JSON: set `status` to `rendered`.

Filenames identify the recipient: e.g. `Smith_Jane_120345_to_Dr_Patel.pdf`, `Smith_Jane_120345_patient_copy.pdf`, `Smith_Jane_120345_hospital_records.pdf`.

### 6.3 LaTeX template

Reuse the existing `letter_template_simple.tex` with the following modifications:

- Professional copies: 11pt body text, standard line spacing.
- Patient copy: 14pt body text with 1.4× line spacing. The exact line spacing factor needs testing with a real letter; 1.4× is the starting point.
- Hospital records copy: 11pt, no postal address block. The "Re:" line, body, and cc list are present as normal.
- "Re:" line between the address block and salutation: patient name, DOB, MRN. This is standard UK clinical correspondence and is already in the existing template.
- C5 window envelope address positioning must be preserved across both font sizes. The address block positioning is absolute (relative to paper edge), so it should be unaffected by body font size. Verify this.
- Font choice: the existing Helvetica is clean and legible at both sizes. Keep it consistent across all copies unless testing reveals a better option for the patient copy.
- Bullet lists: `- item` lines in the body are converted to LaTeX `\begin{itemize}` environments. This is a simple string replacement in the render service before passing to LaTeX.

### 6.4 HTML rendering

A simple HTML template. Inline CSS. No external dependencies.

- Semantic HTML: `<address>`, `<p>`, `<ul>`, `<li>` etc.
- No fixed font sizes; use relative sizing so the recipient can adjust in their email client.
- Include consultant header, contact details, and "Re:" line.
- Plain and clean. No logos or colour.

This is generated alongside the PDFs. It does not replace them.

### 6.5 Yiana Inject Watcher

The append operation is handled by Yiana, not by the render service. This avoids reimplementing `.yianazip` package manipulation in Python. Yiana already has working append logic in Swift.

**How it works:**

1. A small background watcher in Yiana monitors `.letters/inject/` for new PDF files (ignoring any with a `.processing` suffix).
2. The filename encodes the target: `{yiana_target}_{letter_id}.pdf`. The watcher extracts `yiana_target` from the filename by identifying the UUID suffix (the `letter_id` is a standard UUID with hyphens; everything before the last `_` preceding the UUID is the target).
3. Before processing, the watcher renames the file to `{filename}.processing`. This is an atomic operation (`FileManager.moveItem`). If the rename fails, another device's watcher got there first; skip the file. This prevents double-append when Yiana is open on multiple devices simultaneously.
4. The watcher calls Yiana's existing append logic (see below), then deletes the `.processing` file.
5. If the target document is not found, the file is moved to `.letters/unmatched/` (removing the `.processing` suffix) and a warning is logged.

**Existing append code path.** The watcher reuses `ImportService.append(to:importedPDFData:)` (`Yiana/Services/ImportService.swift`), which does the following:

1. Read the `.yianazip` via `DocumentArchive.read(from:)` — extracts `metadata.json`, `content.pdf`, and `format.json` from the ZIP.
2. Load the existing PDF via PDFKit, append the new pages using `PDFDocument.insert(_:at:)`.
3. Update metadata: set new `pageCount`, update `modified` date, set `ocrCompleted = false` (triggers the OCR service to process the new pages).
4. Write back via `DocumentArchive.write()` — stages to a temp directory, creates a new ZIP, then atomically replaces the original using `FileManager.replaceItemAt()` (iCloud-aware).

This is the same code path used by Yiana's share sheet "append to document" action. No new file format handling is needed.

**Metadata update strategy.** There are two metadata update patterns in the codebase. `ImportService` takes the simple path: set `ocrCompleted = false`, update `pageCount`, done. `DocumentViewModel` does more granular `pageProcessingStates` tracking for real-time UI feedback. The inject watcher follows `ImportService`'s approach. It does not know or care about per-page OCR state; that is Devon's responsibility. Setting `ocrCompleted = false` signals "new pages arrived; reprocess." When `DocumentViewModel` next loads the document, it rebuilds its per-page state from the OCR results as they arrive. The watcher does not need to initialise that.

**Where the watcher runs.** The inject watcher runs inside Yiana on whichever device has the app open. On macOS, Yiana typically runs continuously. On iOS/iPad, it runs when the app is foregrounded. Since the Mac Mini render service writes to `inject/` via iCloud, the watcher picks up files when iCloud syncs them to the device running Yiana. In practice, the Mac (where Yiana is most often open) handles injection. If no device has Yiana open, files accumulate in `inject/` until one does — this is acceptable. If multiple devices have Yiana open, the atomic rename to `.processing` (step 3 above) ensures only one device performs the append.

**File coordination.** The watcher must use `NSFileCoordinator` for reads from `inject/` and for the `.yianazip` read-modify-write cycle. iCloud sync can deliver partially-written files; coordinated access ensures the watcher only reads complete files. Yiana's existing document handling already uses coordinated access, so this is consistent with the codebase.

**Scope of change to Yiana.** This is a small addition: a directory watcher that triggers an existing code path. Yiana gains no letter-specific UI, no knowledge of what the PDFs contain, and no dependency on Yiale. It simply appends pages to a named document when asked. This is generic enough that it could serve other use cases (e.g. appending scanned addenda from another source).

**OCR and address extraction.** Setting `ocrCompleted = false` during the append causes Devon's OCR service to reprocess the document on its next scan cycle. It extracts addresses from the letter text automatically. A letter to a new specialist teaches the system that specialist's name, practice, and address. No special handling is needed.

---

## 7. Integration with Existing Systems

| Existing component | Relationship to Yiale |
|---|---|
| `.addresses/*.json` | Read by Yiale for patient/recipient lookup. No writes. |
| `addresses_backend.db` | Not directly used. Yiale reads the JSON files. |
| `extraction_service.py` | Unchanged. Also extracts addresses from appended letters. |
| `letter_template_simple.tex` | Reused and extended for the render service. |
| `letter_generator.py` | Superseded. The render service replaces this. |
| `letter_cli.py` | Superseded. Yiale replaces this workflow. |
| `letter_system_db.py` | Superseded. Letter status is tracked in the draft JSON. |
| `clinic_notes_parser.py` | Not used. Body text is supplied directly. |
| `gp_matcher.py` / `gp_fuzzy_search.py` | Not needed for letter composition. Retained for the extraction pipeline. |
| OCR pipeline | Unchanged. Benefits from letter injection. |
| Yiana app | Small addition: inject watcher (§6.5). No letter-specific UI. Shares iCloud container with Yiale. |

---

## 8. Resolved Questions

| # | Question | Decision |
|---|----------|----------|
| Q1 | One PDF or many? | Separate PDFs per postal recipient, plus a hospital records copy. |
| Q2 | Letter numbering? | No. MRN on the letter and PDF filename are sufficient. |
| Q3 | Patient copy font size? | 14pt body text with ~1.4× line spacing. Derived from role, not stored in JSON. |
| Q4 | Secretary workflow? | Personal deployment; see Appendix A. |
| Q5 | Email workflow? | Share sheet from Yiale. HTML version. |
| Q6 | Draft deletion? | User dismisses from drafts list after reviewing rendered PDFs. Draft JSON deleted on dismissal. |
| Q7 | Address confirmation? | Yes. Confirmation step shows all addresses and the Yiana target document. |
| Q8 | OCR on appended letters? | Desirable. Extracts addresses from the letter; teaches the system new addresses automatically. |
| Q9 | Yiana injection method? | Explicit filename via `yiana_target`. Render service places PDF in `inject/`. Yiana's inject watcher appends using existing Swift logic. No Python `.yianazip` manipulation. |
| Q10 | Print queue location? | `.letters/rendered/` in iCloud. Further copying is a personal deployment choice. |
| Q11 | Hospital records copy? | 11pt, no postal address block. Filed, not posted. |
| Q12 | What goes into Yiana? | One copy (hospital records version) appended to the patient's document. |
| Q13 | Separate app or tab? | Separate app (Yiale). Side-by-side workflow. Shared iCloud container. |
| Q14 | Re: line? | Yes. Patient name, DOB, MRN. Already in existing LaTeX template. |
| Q15 | Body text formatting? | Paragraphs and bullet lists only. No markdown library. |
| Q16 | New patient with no Yiana document? | PDF moved to `.letters/unmatched/`. Manual append via Yiana share sheet. |
| Q17 | iCloud container sharing? | Shared container identifier in both apps' entitlements. No App Group needed. |
| Q18 | Dropbox in core spec? | No. Appendix A only. |
| Q19 | copy_list field? | Removed. CC line derived from `recipients[]`. |
| Q20 | source_document_id? | Removed. `yiana_target` is the single field. Pre-populated from the address data's `document_id`; editable by user. |
| Q21 | font_size per recipient? | Removed. Render service derives from role. |
| Q22 | Correcting a rendered letter? | Compose a new letter. Rendered PDFs and appended Yiana pages are not retracted. Standard clinical practice. |
| Q23 | Hospital records empty address? | Render service omits the postal address block. Stated explicitly in §6.2. |
| Q24 | .yianazip append implementation? | Yiana's inject watcher uses existing Swift append logic. No Python reimplementation. |
| Q25 | Multi-device race condition? | Watcher renames file to `.processing` before appending. Atomic `FileManager.moveItem`; if it fails, another device got there first. |

---

## 9. What This Replaces

The following components become redundant once Yiale is operational:

- `letter_cli.py`
- `letter_system_db.py`
- `clinic_notes_parser.py` (unless still used elsewhere)
- `letter_generator.py` (logic moves into the render service)

These can be archived rather than deleted.

---

## 10. Build Order

A suggested sequence. Each step is independently useful.

1. **Sender config + draft JSON schema.** Define the data format. Write sample files by hand. Validate the schema covers real letters from your practice.
2. **Render service + HTML.** Mac Mini watcher + LaTeX rendering + HTML rendering. Test with hand-written draft JSON files. Confirm PDF quality, envelope positioning, Re: line, hospital records variant (no address block), 14pt patient copy legibility, and HTML email version. HTML is trivial; do it in the same step.
3. **Yiana inject watcher.** Small addition to Yiana: a background directory watcher on `.letters/inject/` that calls `ImportService.append(to:importedPDFData:)`. The watcher renames to `.processing` (atomic; prevents double-append across devices), parses `{yiana_target}` from the filename, locates the matching `.yianazip`, and triggers the existing append path. Roughly 50–80 lines of new code. Test with the render service from step 2: hand-written JSON → render → inject → auto-append → OCR reprocesses → addresses extracted. This gives a complete loop before any Yiale UI exists.
4. **Yiale — Mac.** SwiftUI app: patient search, compose, address confirmation step, drafts list with dismiss, preview, share sheet. Mac first because it is the primary platform.
5. **Yiale — iOS/iPadOS.** Adapt the SwiftUI views for smaller screens. Compose and draft management work; rendering still happens on the Mac Mini.
6. **Cleanup.** Archive superseded components. Confirm end-to-end flow.

---

## Appendix A: Personal Deployment — Dropbox Print Queue

This appendix describes a deployment-specific configuration. It is not part of Yiale's core design.

**Context.** The secretary prints letters from a shared Dropbox folder ("Print me"). Printed letters are moved to a "Printed" subfolder.

**Implementation.** A simple watcher script on the Mac Mini monitors `.letters/rendered/` for new PDFs and copies them to the shared Dropbox folder. This script is independent of the render service.

Other users of Yiale would access rendered PDFs directly from `.letters/rendered/` in iCloud, or set up their own forwarding.
