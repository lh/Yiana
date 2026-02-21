# Yiana macOS UI Component Map — V2

> **Date:** 14 February 2026
> **Scope:** macOS reading and organising interface only (edit view and iOS excluded)
> **Purpose:** Unambiguous label system for discussing UI changes
> **Revision:** V2 — consolidated toolbar layout for Document Read View (Screens B, C, D)

Every visible element has a unique label (e.g. **A4**, **B3a**). Use these labels when
discussing changes so there is no ambiguity about which element is being referenced.

---

## Design Decisions (V2)

This section captures the rationale behind the V2 layout changes. A coding LLM should
treat these as binding constraints when resolving ambiguities during implementation.

### Toolbar consolidation

The original Document Read View had four horizontal layers above the PDF content:

1. Window title bar (B1) — system chrome, back button, document title
2. Navigation path bar (B2) — breadcrumb-style bar with document name and + button
3. Action toolbar (B3) — document title label, Manage Pages, Export PDF, Info
4. PDF toolbar (B4) — sidebar toggle, page navigator, zoom, fit controls

**V2 reduces this to two rows:**

- **Row 1** shares the window title bar with the traffic lights. Contains: back button,
  document title, and the document-level actions (Manage Pages, Export PDF, Info).
- **Row 2** is a slim navigation/zoom bar. Contains: sidebar toggle (left), centred
  page navigator, zoom in/out and fit toggle (right).

The navigation path bar (B2/B2a) is removed entirely — it was a vestige of a previous
iteration and served no current purpose.

### Page navigator positioning

The page navigator (B4b) is **centred to the window**, not to the content area. When
the left sidebar opens or closes, the page navigator does not move. This preserves
muscle memory — the user always reaches for the same screen position regardless of
sidebar state.

### Fit mode toggle

The original layout had two separate buttons: Fit Page (B4e) and Fit Width (B4f).
**V2 merges these into a single toggle button** that cycles between fit-to-height and
fit-to-width. The icon changes to reflect the current mode. This saves toolbar space
and is unambiguous since only one fit mode can be active at a time.

### PDF scaling behaviour

PDFs are fixed-aspect-ratio rendered pages, not reflowing text. When the left sidebar
opens, the PDF **scales down uniformly on both axes** to fit the reduced viewport. The
page is never cropped or clipped. In fit-to-height mode the entire page remains visible;
in fit-to-width mode the page fills the available width and the user scrolls vertically.

### Right sidebar (Info panel) behaviour

The right sidebar (D1) is an **overlay** — it appears on top of the PDF content rather
than pushing it sideways or causing it to rescale. This is acceptable because the Info
panel is a power-user/debugging tool, not a primary reading aid. The existing
implementation of D1 is unchanged in V2.

### Left sidebar modes

The left sidebar retains the Pages/Addresses segmented picker (C1a) at the top.
Behaviour is unchanged from V1.

### Manage Pages sheet

The Manage Pages modal sheet (Screen E) is unchanged in V2. It is triggered by B3a.

---

## Screen A: Document List View (unchanged)


```
┌─────────────────────────────────────────────────────────────────┐
│ [A1] WINDOW TITLE BAR                                          │
│  "Documents (2847)"                                             │
│  Left: (none)        Right: [A2] Select  [A3] Add Menu (+v)    │
│                              [A4] Sort Menu (↕v)                │
│                              [A5] iCloud Sync Indicator (⟳)     │
│                              [A6] Search Field                  │
│                              [A7] Dev Mode Toggle (⟋)           │
│                              [A8] Settings Gear                 │
├─────────────────────────────────────────────────────────────────┤
│ [A9] NAVIGATION PATH BAR   "Documents (2847)"          [A10]+  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ [A11] FOLDERS SECTION HEADER  "Folders"                         │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 📁 BMA                                              >  │    │
│  │ 📁 Billing                                          >  │    │
│  │ 📁 Clinical                                         >  │    │
│  │ 📁 Junk?                                            >  │    │
│  └─────────────────────────────────────────────────────────┘    │
│  [A12] FOLDER ROW  (icon + name + chevron)                      │
│                                                                 │
│ [A13] DOCUMENTS SECTION HEADER  "Documents"                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ ▌Metamorphosis                                         │    │
│  │ ▌14 Feb 2026 at 00:17                                  │    │
│  │─────────────────────────────────────────────────────────│    │
│  │ ▌My Imported Doc 2                                     │    │
│  │ ▌13 Feb 2026 at 23:07                                  │    │
│  │─────────────────────────────────────────────────────────│    │
│  │ ▌...                                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│  [A14] DOCUMENT ROW  (status bar + title + date)                │
│    [A14a] Status Color Bar (left edge tint)                     │
│    [A14b] Document Title                                        │
│    [A14c] Date Subtitle                                         │
│                                                                 │
│ (scrolls to more documents...)                                  │
│                                                                 │
│ [A15] VERSION SECTION (at bottom of list, not visible here)     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘```

### Context menus

- **A12 (folder row):** rename, delete
- **A14 (document row):** rename, move to folder, duplicate, delete

---

## Screen B: Document Read View — V2 (no sidebars)

> Visual reference: `option2-final.jsx` with sidebar closed


```
┌─────────────────────────────────────────────────────────────────┐
│ [B1] ROW 1: TITLE BAR + ACTIONS                    height: 36  │
│  ●●● [B1a]< "Metamorphosis"     [B3a]📁 Manage Pages          │
│  traffic                          [B3b]↗ Export PDF             │
│  lights                           [B3c]ⓘ Info                  │
├─────────────────────────────────────────────────────────────────┤
│ [B4] ROW 2: NAVIGATION BAR                         height: 30  │
│  Left:   [B4a] Sidebar Toggle (▯)                              │
│  Centre: [B4b] Page Navigator  < 1 of 3 >  (centred to window) │
│  Right:  [B4d] Zoom Out (-🔍)                                  │
│          [B4c] Zoom In (+🔍)                                   │
│          [B4ef] Fit Toggle (↕ ↔)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                                                                 │
│                   [B5] PDF CONTENT AREA                         │
│                   (MacPDFViewer / PDFKit NSView)                │
│                   Scales uniformly to fit viewport.             │
│                   Never cropped.                                │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘```

### Row 1 layout detail

Row 1 uses the macOS window title bar region. The traffic light buttons sit at the
standard system position. To the right of the traffic lights: back button (B1a), then
the document title as a non-editable label. Right-aligned: the three document-level
action buttons (B3a, B3b, B3c), each rendered as an icon + text label in the system
accent colour.

### Row 2 layout detail

Row 2 is a three-column grid:

| Column | Alignment | Contents |
|--------|-----------|----------|
| Left | leading | B4a sidebar toggle |
| Centre | centred to window | B4b page navigator in a subtle chip/pill background |
| Right | trailing | B4d zoom out, B4c zoom in, B4ef fit toggle |

The centre column is anchored to the **window centre**, not the content area centre.
This means the page navigator does not shift when the left sidebar opens or closes.

---

## Screen C: Document Read View — V2 (left sidebar open)

> Visual reference: `option2-final.jsx` with sidebar open


```
┌──────────────────────────────────────────────────────────────────┐
│ [B1] ROW 1: TITLE BAR + ACTIONS                                 │
│  ●●● < "Metamorphosis"          Manage Pages  Export PDF  Info   │
├──────────────────────────────────────────────────────────────────┤
│ [B4] ROW 2: NAVIGATION BAR                                       │
│  ▯(active)          < 1 of 3 >              -🔍 +🔍 ↕          │
├────────────┬─────────────────────────────────────────────────────┤
│ [C1] LEFT  │                                                     │
│ SIDEBAR    │                                                     │
│ width:120  │                                                     │
│            │                                                     │
│ [C1a]      │                                                     │
│ ┌────┬────┐│                                                     │
│ │Pgs │Addr││                                                     │
│ └────┴────┘│                                                     │
│            │                                                     │
│ [C1b]      │              [B5] PDF CONTENT AREA                  │
│ THUMBNAIL  │              PDF scales down uniformly to fit       │
│ SCROLL AREA│              the reduced viewport width.            │
│            │              Page nav (B4b) stays window-centred.   │
│ ┌────────┐ │                                                     │
│ │ Page 1 │ │                                                     │
│ └────────┘ │                                                     │
│ [C1c] cell │                                                     │
│ (selected  │                                                     │
│  = blue    │                                                     │
│  border)   │                                                     │
│ ┌────────┐ │                                                     │
│ │ Page 2 │ │                                                     │
│ └────────┘ │                                                     │
│ ┌────────┐ │                                                     │
│ │ Page 3 │ │                                                     │
│ └────────┘ │                                                     │
│            │                                                     │
└────────────┴─────────────────────────────────────────────────────┘```

### Left sidebar modes (C1a picker)

| Mode | Content shown |
|------|--------------|
| **Pages** | Thumbnail grid of all pages (C1b/C1c) |
| **Addresses** | Extracted address cards for the document |

### Sidebar open → PDF scaling

When the sidebar opens, the available width for B5 decreases by the sidebar width
(~120pt). The PDF page scales down **uniformly** (both x and y) so the entire page
remains visible. The page is never cropped or clipped on the right edge. In
fit-to-height mode, the scale factor is `min(viewportH / pageH, viewportW / pageW)`.
In fit-to-width mode, the scale factor is `viewportW / pageW` and the user scrolls
vertically.

---

## Screen D: Document Read View — V2 (right sidebar overlay)

> Visual reference: right sidebar is not shown in the JSX mockup — it overlays
> unchanged from V1. See `DocumentInfoPanel.swift` for current implementation.

The right sidebar is an **overlay** on top of the PDF content. It does not cause the
PDF to rescale or the left sidebar to resize. It is toggled by B3c (Info).


```
┌──────────────────────────────────────────────────────────────────────┐
│ [B1] ROW 1: TITLE BAR + ACTIONS                                     │
├──────────────────────────────────────────────────────────────────────┤
│ [B4] ROW 2: NAVIGATION BAR                                           │
├────────────┬──────────────────────────────┬──────────────────────────┤
│ [C1] LEFT  │                              │ [D1] RIGHT SIDEBAR       │
│ SIDEBAR    │                              │ HEADER (overlay)         │
│ (optional) │                              │  ⓘ "Document Info" [D1a]✕│
│            │                              ├──────────────────────────┤
│ Pages|Addr │                              │ [D2] INFO TAB BAR        │
│            │                              │ ┌────┬────┬────┬─────┐  │
│ ┌────────┐ │                              │ │Addr│Meta│Text│Debug│  │
│ │ Page 1 │ │                              │ └────┴────┴────┴─────┘  │
│ └────────┘ │   [B5] PDF CONTENT AREA      ├──────────────────────────┤
│ ┌────────┐ │   (partially obscured by     │ [D3] TAB CONTENT AREA    │
│ │ Page 2 │ │    right sidebar overlay)    │                          │
│ └────────┘ │                              │ (when Text tab selected:)│
│ ┌────────┐ │                              │ [D3a] OCR Status Badge   │
│ │ Page 3 │ │                              │   "● Completed"          │
│ └────────┘ │                              │ [D3b] OCR Metadata       │
│            │                              │   Processed date         │
│            │                              │   Confidence %           │
│            │                              │   Source                 │
│            │                              │ [D3c] Reprocess Button   │
│            │                              │   (emoji dropdown)       │
│            │                              │ [D3d] Search in Text     │
│            │                              │   🔍 "Search in text..." │
│            │                              │ [D3e] OCR Text Content   │
│            │                              │   (scrollable monospace) │
│            │                              │                          │
└────────────┴──────────────────────────────┴──────────────────────────┘```

### Right sidebar tabs (D2) — unchanged

| Tab | Label | Content |
|-----|-------|---------|
| **D2a** | Addresses | Extracted patient/GP address cards (editable fields) |
| **D2b** | Metadata | Document metadata: title, dates, tags, folder, OCR status |
| **D2c** | Text | OCR text with status badge, confidence, and search |
| **D2d** | Debug | File size, raw JSON viewer, internal state |

---

## Screen E: Manage Pages Sheet (modal) — unchanged

> No visual changes in V2. See `PageManagementView.swift` for current implementation.


```
        ┌──────────────────────────────────────────┐
        │ [E1] SHEET TITLE  "Manage Pages"         │
        │                                          │
        │  ┌──────┐  ┌──────┐  ┌──────┐           │
        │  │      │  │      │  │      │           │
        │  │  P1  │  │  P2  │  │  P3  │           │
        │  │      │  │      │  │      │           │
        │  └──────┘  └──────┘  └──────┘           │
        │  [E2] PAGE THUMBNAIL GRID                │
        │   (tap to select; blue border = selected)│
        │                                          │
        ├──────────────────────────────────────────┤
        │ [E3] PAGE ACTION TOOLBAR                 │
        │  [E3a] Copy                              │
        │  [E3b] Cut                               │
        │  [E3c] Paste                             │
        │  [E3d] Move Left                         │
        │  [E3e] Move Right                        │
        │  [E3f] Delete Selected                   │
        │  [E3g] Done                              │
        └──────────────────────────────────────────┘```

---

## Quick Reference: All Labels

### Active labels

| Label | Element | Screen | V2 notes |
|-------|---------|--------|----------|
| **A1** | Window title bar (list view) | A | |
| **A2** | Select mode button | A | |
| **A3** | Add menu (+ dropdown) | A | |
| **A4** | Sort menu (dropdown) | A | |
| **A5** | iCloud sync indicator | A | |
| **A6** | Search field | A | |
| **A7** | Dev mode toggle | A | |
| **A8** | Settings gear | A | |
| **A9** | Navigation path bar | A | |
| **A10** | Path bar "+" button | A | |
| **A11** | Folders section header | A | |
| **A12** | Folder row (icon + name + chevron) | A | |
| **A13** | Documents section header | A | |
| **A14** | Document row | A | |
| **A14a** | — Status color bar (left edge) | A | |
| **A14b** | — Document title | A | |
| **A14c** | — Date subtitle | A | |
| **A15** | Version section (bottom of list) | A | |
| **B1** | Row 1: title bar + actions | B, C, D | **Changed:** now shares traffic light row; contains back, title, and actions |
| **B1a** | Back button | B, C, D | Moved into Row 1 next to traffic lights |
| **B3a** | Manage Pages button (icon + text) | B, C, D | Moved into Row 1, right-aligned |
| **B3b** | Export PDF button (icon + text) | B, C, D | Moved into Row 1, right-aligned |
| **B3c** | Info toggle button (icon + text) | B, C, D | Moved into Row 1, right-aligned |
| **B4** | Row 2: navigation bar | B, C, D | **Changed:** slim bar, three-column grid layout |
| **B4a** | Sidebar toggle | B, C, D | Row 2, left column |
| **B4b** | Page navigator (< N of M >) | B, C, D | Row 2, centre column, **centred to window** |
| **B4c** | Zoom in | B, C, D | Row 2, right column |
| **B4d** | Zoom out | B, C, D | Row 2, right column |
| **B4ef** | Fit toggle (cycles height ↔ width) | B, C, D | **Merged:** replaces separate B4e and B4f |
| **B5** | PDF content area (PDFKit) | B, C, D | Scales uniformly, never cropped |
| **C1** | Left sidebar (container) | C, D | |
| **C1a** | Sidebar mode picker (Pages / Addresses) | C, D | |
| **C1b** | Thumbnail scroll area | C, D | |
| **C1c** | Thumbnail cell (one per page) | C, D | |
| **D1** | Right sidebar header (overlay) | D | **Clarified:** overlay, does not push content |
| **D1a** | Close sidebar button | D | |
| **D2** | Info tab bar | D | |
| **D2a** | — Addresses tab | D | |
| **D2b** | — Metadata tab | D | |
| **D2c** | — Text tab | D | |
| **D2d** | — Debug tab | D | |
| **D3** | Tab content area | D | |
| **D3a** | OCR status badge | D (Text tab) | |
| **D3b** | OCR metadata (date, confidence, source) | D (Text tab) | |
| **D3c** | Reprocess button | D (Text tab) | |
| **D3d** | Search in text field | D (Text tab) | |
| **D3e** | OCR text content (scrollable) | D (Text tab) | |
| **E1** | Manage Pages sheet title | E | |
| **E2** | Page thumbnail grid | E | |
| **E3** | Page action toolbar | E | |
| **E3a** | Copy button | E | |
| **E3b** | Cut button | E | |
| **E3c** | Paste button | E | |
| **E3d** | Move Left button | E | |
| **E3e** | Move Right button | E | |
| **E3f** | Delete Selected button | E | |
| **E3g** | Done button | E | |

### Retired labels

| Label | Was | Reason |
|-------|-----|--------|
| **B2** | Navigation path bar | Removed — vestige of previous iteration, no current function |
| **B2a** | Path bar "+" button | Removed with B2 |
| **B3** | Action toolbar (separate row) | Absorbed into B1 (Row 1) |
| **B4e** | Fit Page (separate button) | Merged into B4ef toggle |
| **B4f** | Fit Width (separate button) | Merged into B4ef toggle |
| **B6** | Dead space below PDF | Eliminated — PDF now scales to fill viewport |

---

## Navigation Flow


```
Screen A                Screen B/C/D              Screen E
(Document List)  ───>   (Document Read)  ───>     (Manage Pages)
                click        │                    modal sheet
               doc row       │ B3c toggles ──> D (right sidebar, overlay)
                             │ B4a toggles ──> C (left sidebar, PDF rescales)
                             │ B3a opens   ──> E (manage pages)```

---

## Implementation Constraints

These constraints must be respected when implementing the V2 layout:

1. **B4b (page navigator) is centred to the window frame**, not to the PDF content
   area. Use a three-column grid on Row 2 with the centre column anchored to the
   window. The navigator must not shift position when C1 (left sidebar) opens or
   closes.

2. **PDF scaling is uniform.** When the left sidebar opens, recalculate the PDF scale
   as `min(viewportH / pageH, viewportW / pageW)` for fit-to-height, or
   `viewportW / pageW` for fit-to-width. The page aspect ratio is always preserved.
   The page is never clipped or cropped.

3. **The right sidebar (D1) is an overlay.** It sits on top of B5. It does not
   cause B5 to resize or the PDF to rescale. It does not affect the left sidebar.

4. **B4ef is a single toggle button.** It cycles between fit-to-height and
   fit-to-width. The icon should change to indicate the current mode. Only one mode
   is active at a time.

5. **Row 1 (B1) uses the macOS title bar region.** The traffic light buttons are at
   their standard system position. Toolbar items sit inline to the right of the
   traffic lights. This is achieved via `.toolbar` in SwiftUI with appropriate
   placement, or by setting `titlebarAppearsTransparent` and managing layout manually.

6. **Row 1 height: ~36pt. Row 2 height: ~30pt.** Total toolbar chrome: ~66pt,
   down from ~130pt+ in V1.

---

## Source files (for code reference)

| Screen | Primary source file |
|--------|-------------------|
| A | `Yiana/Views/DocumentListView.swift` |
| B | `Yiana/Views/DocumentReadView.swift` |
| B5 | `Yiana/Views/MacPDFViewer.swift` |
| C1 | `Yiana/Views/ThumbnailSidebarView.swift` (in MacPDFViewer) |
| D | `Yiana/Views/DocumentInfoPanel.swift` |
| E | `Yiana/Views/PageManagementView.swift` |

---

## Reference Mockup

An interactive React/JSX mockup of the V2 layout is available as `option2-final.jsx`.
This demonstrates the toolbar layout, sidebar toggle, PDF scaling behaviour, and
Pages/Addresses mode picker. It is a **visual reference only** — the production app
is SwiftUI/AppKit, not React.
