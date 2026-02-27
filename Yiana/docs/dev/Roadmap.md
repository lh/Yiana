# Yiana Roadmap

**Purpose**: Current status and planned features for Yiana
**Audience**: Developers and contributors
**Last Updated**: 2026-02-25

---

## Current Status (February 2026)

### Completed Features

#### Core Document Management
- **UIDocument/NSDocument architecture** - iOS/iPadOS uses UIDocument, macOS uses NSDocument
- **.yianazip package format** - ZIP archive (metadata.json + content.pdf + format.json) via `YianaDocumentArchive` package
- **iCloud sync** - Automatic sync via iCloud Drive
- **Document creation** - Title required at creation time
- **Document import** - Import external PDFs as new documents or append to existing
- **Bulk import** (macOS) - Multi-file import with SHA256 duplicate detection, progress tracking, per-file timeout
- **Bulk export** (macOS) - Export with folder structure preservation
- **Document deletion** - With confirmation dialog
- **Duplicate scanner** (macOS) - SHA256-based detection with review UI

#### Folders & Organization
- **Folders** - Create, rename, delete with nested subfolder support
- **Drag-and-drop** (macOS) - Move documents between folders, import PDFs from Finder
- **Drag-and-drop** (iOS) - Move documents to sidebar folders on iPad
- **Sort options** - By date, title, size

#### Scanning & Capture
- **VisionKit integration** - Automatic edge detection and capture
- **Three scan modes**: Color, Doc (B&W), Text (markdown editor)
- **Multi-page scanning** - Capture multiple pages in one session
- **Automatic capture** - No manual shutter button needed

#### Text Pages
- **Markdown editor** - UITextView wrapper with syntax highlighting
- **Live preview** - Real-time PDF rendering as you type
- **Provisional page composition** - In-memory PDF combining (saved + draft)
- **Draft management** - Autosave and recovery system
- **Supported markdown**: Headers, bold, italic, lists, blockquotes, horizontal rules
- **Toolbar actions** - Queue pattern to prevent SwiftUI state crashes
- **Split view (iPad)** - Editor and preview side-by-side
- **Finalization** - Text pages become permanent PDFs

#### Search
- **GRDB/FTS5 search index** - Full-text search with BM25 ranking
- **Porter stemming** - "running" matches "run", etc.
- **Snippet generation** - Context around matches with highlighting
- **Page-level results** - Results show specific page numbers
- **ValueObservation** - Reactive list updates from database changes
- **Placeholder support** - iCloud files not yet downloaded appear in list

#### OCR Processing
- **On-device OCR** - Apple Vision framework (VNRecognizeTextRequest) for immediate recognition
- **Server OCR** - YianaOCRService (Swift CLI, Mac mini) for batch processing
- **OCR source tracking** - Metadata records whether OCR was on-device, server, or embedded
- **Confidence scores** - Displayed in document info panels
- **JSON/XML/hOCR results** - Server results saved to `.ocr_results/`

#### Page Operations
- **Page copy/cut/paste** - Between documents on both platforms
- **Page reordering** - Drag in thumbnail grid
- **Page deletion** - With confirmation
- **Restore cut** - Undo cut operations within same document

#### Print
- **macOS** - Native print via Cmd+P, toolbar button, NSPrintOperation
- **iOS** - Via share sheet (UIActivityViewController includes Print)

#### Address Extraction
- **In-app viewing** - Extracted patient, GP, specialist data shown per document
- **Inline editing** - Users can correct and override extracted data
- **Prime address system** - Mark primary contacts
- **Address type settings** - Customizable templates, icons, colors
- **Backend processing** - Python service on Mac mini extracts from OCR results

#### Settings
- **Paper size** - A4 or US Letter
- **Sidebar position** (iPad) - Left or Right
- **Thumbnail size** (iPad) - Small, Medium, Large
- **Developer mode** - Hidden toggle (tap version 7 times), session-based
- **Developer tools** - Search index reset, OCR tools, debug info

#### PDF Viewing
- **PDFKit integration** - Native PDF viewing on all platforms
- **Read-only mode** - No annotations to avoid memory issues
- **1-based page indexing** - Consistent page numbering throughout
- **Mixed page size support** - Handles A4 and US Letter in same document
- **Page navigation** - Direct page jumps, swipe gestures

#### UI/UX
- **SwiftUI** - Modern declarative UI
- **Platform-specific layouts** - iPhone (compact), iPad (regular), macOS
- **Swipe gestures** - Left/right for pages, up for page grid
- **Page management grid** - Visual page overview with thumbnails
- **Keyboard shortcuts** - Full macOS keyboard support
- **Dark mode** - Full support

### Known Limitations

1. **Tags** - Metadata field exists and displays read-only; no UI to add/edit/filter by tags
2. **No inline images in text pages** - Markdown image syntax not supported
3. **Limited markdown** - Subset of markdown (no tables, code blocks)
4. **No post-finalization editing** - Text pages permanent once finalized
5. **Bulk import/export macOS only** - iOS uses standard share sheet
6. **Duplicate scanner macOS only** - No iOS UI
7. **No camera scanning on macOS** - Hardware limitation

---

## Planned Work

### High Priority

#### macOS Text Markup Completion
- Implement PDFAnnotation creation for text selection
- Add markup toolbar (highlight, underline, strikethrough)
- Persist annotations in PDF

#### Tags System
- UI for adding/editing/removing tags
- Filter by tags in document list
- Tag suggestions and autocomplete

### Medium Priority

#### Extended Markdown Support
- Tables
- Code blocks with syntax highlighting
- Task lists
- Internal links

#### iOS Bulk Operations
- Bulk import UI for iOS/iPadOS
- Multi-select export on iOS

#### Multiple Provisional Pages
- Support multiple text page drafts per document

### Low Priority

#### Advanced Search
- Boolean operators (AND, OR, NOT)
- Search within document
- Search history

#### Accessibility Improvements
- VoiceOver optimization
- Dynamic Type support improvements

---

## Technical Debt

### Code Quality
- [ ] Increase test coverage to 80%+ across all modules
- [ ] Add integration tests for major workflows
- [ ] Set up CI/CD pipeline with automated testing
- [ ] Add performance regression tests

### Architecture
- [ ] Refactor search to use async/await consistently
- [ ] Consolidate document loading/saving logic
- [ ] Extract markdown rendering to separate package

### Documentation
- [ ] Add more ADRs for recent decisions
- [ ] Update diagrams as features evolve

---

## Historical Context

**Original plan** (`PLAN.md`):
- Phase 1-2: Core models and document repository
- Phase 3-4: ViewModels and basic UI
- Phase 5-8: Scanner, PDF viewer, iCloud, polish
- All 8 phases completed (2024-2025)

**Features added beyond original plan**:
- Text pages with markdown editor
- GRDB/FTS5 search index with BM25 ranking
- On-device OCR (Vision framework)
- Folders with nesting and rename
- Bulk import/export with duplicate detection
- Page copy/cut/paste between documents
- Print support (macOS)
- Duplicate scanner
- Address extraction system
- Settings and developer tools
- Drag-and-drop (macOS full, iOS sidebar)

---

## Contributing

Interested in working on a roadmap item?

1. Check the [GitHub Issues](https://github.com/lh/Yiana/issues) for the feature
2. Comment to express interest and get assigned
3. Follow TDD process for all changes
4. Create PR when ready

**First-time contributors**: Look for issues tagged `good-first-issue`

---

## Feedback

Have ideas for the roadmap?

- Create a [GitHub Issue](https://github.com/lh/Yiana/issues/new) with "Feature Request" label
- Describe the problem you're trying to solve
- Propose a solution (optional)
