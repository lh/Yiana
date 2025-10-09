# Yiana Roadmap

**Purpose**: Current status and planned features for Yiana
**Audience**: Developers and contributors
**Last Updated**: 2025-10-08

---

## Current Status (October 2025)

### ✅ Completed Features

#### Core Document Management
- **UIDocument/NSDocument architecture** - iOS/iPadOS uses UIDocument, macOS uses NSDocument
- **.yianazip package format** - Metadata + PDF in single file with separator
- **iCloud sync** - Automatic sync via iCloud Drive
- **Document creation** - Title required at creation time
- **Document import** - Import external PDFs as new documents or append to existing
- **Document deletion** - With confirmation dialog

#### Scanning & Capture
- **VisionKit integration** - Automatic edge detection and capture
- **Three scan modes**:
  - **Color** - Full color scanning
  - **Doc (Monochrome)** - Black & white, center position (visual default)
  - **Text** - Text page creation with markdown editor
- **Multi-page scanning** - Capture multiple pages in one session
- **Automatic capture** - No manual shutter button needed

#### Text Pages
- **Markdown editor** - UITextView wrapper with syntax highlighting
- **Live preview** - Real-time PDF rendering as you type
- **Provisional page composition** - In-memory PDF combining (saved + draft)
- **Draft management** - Autosave and recovery system
- **Supported markdown**:
  - Headers (H1, H2, H3)
  - Bold (`**text**`)
  - Italic (`*text*`)
  - Lists (bulleted and numbered)
  - Blockquotes (`> quote`)
  - Horizontal rules (`---`)
- **Toolbar actions** - Queue pattern to prevent SwiftUI state crashes
- **Split view (iPad)** - Editor and preview side-by-side
- **Finalization** - Once done, text pages become permanent PDFs

#### Search
- **Full-text search** - Search document titles and OCR text
- **Page-level results** - Results show specific page numbers
- **Snippet preview** - Context around search matches
- **OCR integration** - Searches text extracted by backend OCR service

#### OCR Processing (Backend)
- **YianaOCRService** - Swift CLI running on Mac mini
- **Vision framework** - Text recognition using Apple's Vision API
- **JSON results** - OCR results saved to `.ocr_results/` directory
- **Metadata integration** - Plain text extracted for search

#### PDF Viewing
- **PDFKit integration** - Native PDF viewing on iOS/iPadOS/macOS
- **Read-only mode** - No annotations to avoid memory issues
- **1-based page indexing** - Consistent page numbering throughout app
- **Mixed page size support** - Handles A4 and US Letter in same document
- **Page navigation** - Direct page jumps, swipe gestures

#### UI/UX
- **SwiftUI** - Modern declarative UI
- **Platform-specific layouts** - iPhone (compact), iPad (regular), macOS
- **Swipe gestures** - Swipe up for page grid, swipe down for document info
- **Page management grid** - Visual page overview with thumbnails
- **Visual indicators** - Draft badge and border for provisional pages

### 🔄 Current Branch Work

**Branch**: `feature/text-page-editor`
- Text page editor styling refinements
- Markdown support improvements
- Search cancellation handling
- Status indicator performance improvements

### ❌ Known Limitations

1. **Single draft at a time** - Only one provisional text page per document
2. **No inline images** - Markdown image syntax not supported
3. **Limited markdown** - Subset of markdown (no tables, code blocks)
4. **No post-finalization editing** - Text pages permanent once finalized
5. **macOS markup incomplete** - Text markup on macOS not fully implemented

---

## Roadmap Q4 2025

### High Priority 🔴

#### 1. macOS Text Markup Completion
**Goal**: Complete text markup/annotation system for macOS

**Tasks**:
- [ ] Implement PDFAnnotation creation for text selection
- [ ] Add markup toolbar (highlight, underline, strikethrough)
- [ ] Persist annotations in PDF
- [ ] Test with large documents

**Estimate**: 2-3 weeks
**Status**: Design docs exist in `docs/`

#### 2. Backup & Restore System
**Goal**: Export/import documents for backup

**Tasks**:
- [ ] Export single document as .yianazip
- [ ] Export all documents as archive
- [ ] Import from .yianazip files
- [ ] Import from archive
- [ ] Verify data integrity after restore

**Estimate**: 1-2 weeks
**Status**: Test plan exists (`BackupSystem-TestPlan.md`)

#### 3. Performance Optimization
**Goal**: Improve app performance for large documents

**Tasks**:
- [ ] Profile search performance with 100+ documents
- [ ] Optimize provisional page composition caching
- [ ] Reduce memory usage in PDF viewer
- [ ] Implement progressive PDF rendering
- [ ] Add performance benchmarks to test suite

**Estimate**: 2-3 weeks

### Medium Priority 🟡

#### 4. Extended Markdown Support
**Goal**: Add more markdown features to text pages

**Tasks**:
- [ ] Tables
- [ ] Code blocks with syntax highlighting
- [ ] Footnotes
- [ ] Task lists (`- [ ] Task`)
- [ ] Internal links (jump to other pages)

**Estimate**: 2-3 weeks
**Blocked by**: Need to decide on renderer (current vs third-party)

#### 5. Multiple Provisional Pages
**Goal**: Support multiple text page drafts per document

**Tasks**:
- [ ] Refactor `ProvisionalPageManager` to handle array of drafts
- [ ] Update provisional page range tracking (single → array)
- [ ] Update UI to show multiple draft indicators
- [ ] Update finalization logic to handle multiple pages

**Estimate**: 1-2 weeks
**Migration path**: Documented in ADR-002

#### 6. Custom Fonts & Themes
**Goal**: Allow users to customize text page appearance

**Tasks**:
- [ ] Font picker for text pages
- [ ] Theme system (light/dark/custom)
- [ ] Font size adjustments
- [ ] Line spacing controls
- [ ] Preview theme in editor

**Estimate**: 1-2 weeks

#### 7. Document Organization
**Goal**: Improve document management

**Tasks**:
- [ ] Folders/categories for documents
- [ ] Tags system
- [ ] Favorites
- [ ] Sort options (date, title, size)
- [ ] Filter by tags, folders, date range

**Estimate**: 2-3 weeks

### Low Priority 🟢

#### 8. Export Options
**Goal**: Export documents in various formats

**Tasks**:
- [ ] Export individual pages as images
- [ ] Export text pages as standalone markdown
- [ ] Export OCR results as text file
- [ ] Export to PDF/A for archival
- [ ] Batch export

**Estimate**: 1-2 weeks

#### 9. Advanced Search
**Goal**: Enhance search capabilities

**Tasks**:
- [ ] Boolean operators (AND, OR, NOT)
- [ ] Regex search
- [ ] Search history
- [ ] Saved searches
- [ ] Search within document

**Estimate**: 1-2 weeks

#### 10. Accessibility Improvements
**Goal**: Better accessibility support

**Tasks**:
- [ ] VoiceOver optimization
- [ ] Dynamic Type support
- [ ] Keyboard shortcuts (macOS)
- [ ] High contrast mode
- [ ] Accessibility audit

**Estimate**: 2-3 weeks

---

## Long-Term Vision (2026+)

### Collaboration Features
- **Shared documents** - iCloud sharing with other users
- **Comments** - Add comments to specific pages/regions
- **Change tracking** - See document edit history

### OCR Enhancements
- **Incremental OCR** - Process only new pages when appending
- **Priority queue** - User-initiated OCR gets higher priority
- **Multi-language support** - Non-English document recognition
- **Quality metrics** - Confidence scores and UI indicators

### Platform Expansion
- **watchOS companion** - Quick document access
- **Shortcuts integration** - Automate workflows
- **macOS Quick Look plugin** - Preview .yianazip in Finder

### Advanced Features
- **Form filling** - Fill PDF forms
- **Digital signatures** - Sign documents
- **Encryption** - Password-protect documents
- **Templates** - Reusable document templates

---

## Technical Debt & Improvements

### Code Quality
- [ ] Increase test coverage to 80%+ across all modules
- [ ] Add integration tests for major workflows
- [ ] Set up CI/CD pipeline with automated testing
- [ ] Add performance regression tests
- [ ] Document all public APIs with code comments

### Architecture
- [ ] Refactor search to use async/await consistently
- [ ] Consolidate document loading/saving logic
- [ ] Extract markdown rendering to separate package
- [ ] Improve error handling consistency

### Documentation
- [ ] Complete user documentation (`docs/user/`)
- [ ] Add more ADRs for recent decisions
- [ ] Create video tutorials
- [ ] Write API reference documentation
- [ ] Update diagrams as features evolve

### Dependencies
- [ ] Evaluate GRDB.swift integration for metadata storage
- [ ] Consider SwiftLint for code style enforcement
- [ ] Evaluate markdown rendering libraries

---

## Release Schedule

### Version 1.1 (November 2025)
**Focus**: Stability & Performance

- macOS text markup completion
- Backup & restore system
- Performance optimizations
- Bug fixes from TestFlight feedback

### Version 1.2 (December 2025)
**Focus**: User Experience

- Extended markdown support
- Multiple provisional pages
- Custom fonts & themes
- Document organization (folders, tags)

### Version 1.3 (Q1 2026)
**Focus**: Advanced Features

- Export options
- Advanced search
- Accessibility improvements
- Collaboration features (initial)

---

## Decision-Making Process

### Feature Prioritization

**Criteria**:
1. **User impact** - How many users benefit?
2. **Complexity** - Development time vs value
3. **Dependencies** - Blockers or prerequisites?
4. **Risk** - Potential for bugs or regressions?
5. **Strategic value** - Long-term product vision

**Priority levels**:
- **High (🔴)**: Critical bugs, major features, user-requested
- **Medium (🟡)**: Nice-to-have, enhancements
- **Low (🟢)**: Future considerations, exploratory

### Adding to Roadmap

**Process**:
1. Create GitHub issue with feature request
2. Discuss with team/community
3. Create ADR if architectural impact
4. Estimate effort and assign priority
5. Add to appropriate milestone

### Removing from Roadmap

**Reasons**:
- User feedback indicates low value
- Technical constraints make infeasible
- Better alternative identified
- Out of scope for project vision

**Process**: Archive issue with explanation, update roadmap

---

## Contributing

Interested in working on a roadmap item?

1. Check the [GitHub Issues](https://github.com/lh/Yiana/issues) for the feature
2. Comment to express interest and get assigned
3. Read [`Contributing.md`](Contributing.md) for workflow
4. Follow TDD process for all changes
5. Create PR when ready

**First-time contributors**: Look for issues tagged `good-first-issue`

---

## Feedback

Have ideas for the roadmap?

- Create a [GitHub Issue](https://github.com/lh/Yiana/issues/new) with "Feature Request" label
- Describe the problem you're trying to solve
- Propose a solution (optional)
- Include mockups/examples if helpful

We review feature requests monthly and update the roadmap accordingly.

---

## Historical Context

**Original plan** (`PLAN.md`):
- Phase 1-2: Core models and document repository ✅ Complete
- Phase 3-4: ViewModels and basic UI ✅ Complete
- Phase 5-8: Scanner, PDF viewer, iCloud, polish ✅ Complete

**Actual implementation**:
- Phases 1-8 completed (2024-2025)
- Additional features added based on usage:
  - Text pages with markdown editor (not in original plan)
  - Search with OCR integration (expanded from original scope)
  - Provisional page composition (new pattern)
  - Advanced gesture system (UX improvement)

**Lessons learned**:
- TDD approach worked well, caught many bugs early
- Platform-specific code clearer than forced abstractions
- UIDocument/NSDocument simpler than Core Data for this use case
- User feedback critical for prioritization

---

**Last Updated**: 2025-10-08 | **Next Review**: 2025-11-01
