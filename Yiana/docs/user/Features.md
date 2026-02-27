# Yiana Features Overview

**Yiana** is a document scanning and PDF management app for iOS, iPadOS, and macOS. This guide covers all features in detail.

---

## Table of Contents

- [Document Scanning](#document-scanning)
- [Text Pages](#text-pages)
- [Document Organization](#document-organization)
- [Search](#search)
- [Page Management](#page-management)
- [Navigation and Gestures](#navigation-and-gestures)
- [iCloud Sync](#icloud-sync)
- [Import and Export](#import-and-export)
- [Print](#print)
- [Drag and Drop](#drag-and-drop)
- [Duplicate Scanner](#duplicate-scanner)
- [Address Extraction](#address-extraction)
- [Settings](#settings)
- [Platform Features](#platform-features)

---

## Document Scanning

### Camera Scanning (iOS and iPadOS)

Yiana uses VisionKit to scan documents with your device's camera.

#### Scan Modes

Three buttons appear at the bottom of the document view:

**"Scan"** (left, colorful circle button)
- Best for: Photos, colorful documents, forms
- Output: Full-color PDF
- Auto-enhancement: Yes
- Auto-crop: Yes

**"Doc"** (center, gray circle button) - default position
- Best for: Text documents, receipts, contracts
- Output: Black and white PDF
- Auto-enhancement: Optimized for text clarity
- Auto-crop: Yes

**"Text"** (right) - Create text page

#### Scanning Tips

**Best Practices**:
- Use good lighting (natural light is best)
- Place document on contrasting background
- Hold camera steady
- Ensure all corners are visible
- Review each scan before saving

**Multi-Page Scanning**:
- Camera automatically detects and captures documents
- Review and tap "Save" or "Retake"
- Tap scan button again to add more pages
- Pages append in order

**Automatic Scan Quality**:
- VisionKit auto-detects edges and crops
- Auto-enhances contrast and brightness
- Removes shadows and corrects perspective
- Outputs high-resolution PDF
- No manual shutter button - camera captures automatically

---

## Text Pages

Create typed notes that become permanent PDF pages in your documents.

### Creating Text Pages

1. Open a document
2. Tap "Text" button (bottom right)
3. Type your content
4. Use toolbar for formatting
5. Tap "Done"

### Markdown Editor

The text editor supports simple markdown formatting:

#### Headers
```
# Heading 1
## Heading 2
### Heading 3
```

Use the "Heading" toolbar button to apply.

#### Text Formatting

**Bold text**:
- Toolbar: Tap **B** button
- Markdown: `**bold text**`

*Italic text*:
- Toolbar: Tap *I* button
- Markdown: `*italic text*`

#### Lists

**Bulleted lists**:
- Toolbar: Tap bullet icon
- Markdown: Start line with `- `

**Numbered lists**:
- Toolbar: Tap numbered icon
- Markdown: Start line with `1. `

#### Other Elements

**Horizontal divider**:
- Toolbar: Tap horizontal line icon
- Markdown: Type `---`

**Blockquotes**:
- Toolbar: Tap quote icon
- Markdown: Start line with `> `

### Preview Mode

**iPad** (split view):
- Editor on left
- Live preview on right
- Updates as you type

**iPhone** (single view):
- Tap "Preview" button to toggle
- See rendered output
- Tap "Editor" to return

### Text Page Behavior

**"Pen and Paper" Philosophy**:
- Text pages are **drafts** while editing
- Become **permanent PDF pages** when you exit the note
- Cannot be edited after exiting (by design)
- Can create new text page if you need to add more

**Page Position**:
- Text pages always append to the end
- After finalizing, appear as regular PDF pages
- Can be reordered like any other page

---

## Document Organization

### Folders

Organize documents into folders for easy access.

#### Creating Folders

1. Tap **+** button (top right)
2. Select "New Folder"
3. Name the folder
4. Tap "Create"

#### Navigating Folders

- **Tap** folder to open
- **Back button** to go up one level
- **Breadcrumb trail** shows current path (macOS)

#### Renaming Folders

1. Right-click (macOS) or long press (iOS) a folder
2. Select "Rename"
3. Enter the new name
4. Tap "Rename" to confirm

#### Nested Folders

Create folders within folders for hierarchical organization. There is no depth limit.

#### Moving Documents

**Method 1** (drag and drop - macOS, iPad sidebar):
- Long press document
- Drag to folder
- Release to drop

**Method 2** (move command):
- Long press document
- Select "Move"
- Choose destination folder

### Document Metadata

Each document stores:
- **Title**: Editable name
- **Created date**: When first scanned/created
- **Modified date**: Last edit timestamp
- **Page count**: Number of pages
- **OCR status**: Whether text extraction is complete
- **OCR source**: On-device, server, or embedded
- **OCR confidence**: Recognition accuracy percentage

---

## Search

Full-text search across all documents, powered by GRDB/FTS5.

### What Gets Searched

- **Document titles** (weighted heavily in ranking)
- **Scanned text** (via on-device or server OCR)
- **Text pages** (typed content)

### Search Features

#### Real-Time Results
- Results appear as you type
- Sorted by BM25 relevance ranking
- Title matches ranked higher than content matches

#### Search Highlighting
- Search terms highlighted in snippets
- Jump directly to matching page
- Context shown around matches

#### Porter Stemming
- "running" matches "run"
- "documents" matches "document"
- Diacritics handled (e.g., "cafe" matches "cafe")

### Search Tips

**Be specific**:
- "receipt october" better than just "receipt"
- Include dates, amounts, vendor names

**Case insensitive**:
- "coffee", "Coffee", "COFFEE" all match

**Partial matches**:
- "oct" matches "October"
- "star" matches "Starbucks"

### OCR Processing

**On-Device OCR** (immediate):
- Uses Apple's Vision framework
- Runs automatically when you scan or open a document
- Results available within seconds
- Works offline

**Server OCR** (background):
- Runs on Mac mini server (if configured)
- Processes documents automatically
- Higher accuracy for complex layouts
- Text extraction happens in background

Both OCR sources feed into the same search index.

---

## Page Management

### Viewing All Pages

**Gesture**: Swipe up on any page
**Result**: Thumbnail grid of all pages

### Page Operations

#### Reordering Pages
1. Swipe up to view page grid
2. Long press a page
3. Drag to new position
4. Release to drop
5. Changes save automatically

#### Deleting Pages
1. Swipe up to view page grid
2. Long press page to delete
3. Tap "Delete"
4. Confirm deletion

**Warning**: Page deletion is permanent.

#### Copy/Cut/Paste Pages

Pages can be copied or cut from one document and pasted into another.

**macOS**:
- Select pages in the grid
- Cmd+C to copy, Cmd+X to cut, Cmd+V to paste
- Also available from Edit > Pasteboard menu

**iOS/iPadOS**:
- Select pages in the grid
- Use the Copy, Cut, and Paste buttons in the bottom toolbar
- "Restore Cut" button appears if you need to undo a cut

Pages transfer between documents -- copy from one, open another, paste.

#### Page Navigation
- **Tap page** in grid to jump to it
- **Swipe left/right** within grid to scroll
- **Tap "Done"** or swipe down to exit grid

### Page Indicators

When viewing a multi-page document:
- **Page counter** shows at bottom (e.g., "Page 3 of 10")
- **Current page** highlighted in grid
- **Draft pages** show yellow border (before finalization)

---

## Navigation and Gestures

### Swipe Gestures

**While viewing a document**:

| Gesture | Action |
|---------|--------|
| Swipe left | Next page |
| Swipe right | Previous page |
| Swipe up | View page grid |

**Important**: Swipe up only works when page is at fit-to-screen zoom (not zoomed in).

### Zoom Gestures

| Gesture | Action |
|---------|--------|
| Pinch out | Zoom in |
| Pinch in | Zoom out |
| Double-tap | Fit to screen |
| Two-finger tap | Zoom to fit width |

### Button Controls

**Document view**:
- **Back arrow**: Return to document list
- **Title**: Tap to edit
- **Export**: Share as PDF

**Bottom toolbar** (iOS, left to right):
- **Scan**: Color scan
- **Doc**: B&W document scan (center - default position)
- **Text**: Create text page

---

## iCloud Sync

Documents automatically sync across your Apple devices.

### How It Works

**Automatic**:
- Documents save to iCloud Documents
- Sync happens in background
- No manual action needed

**Cloud Container**:
- Location: `iCloud Drive/Yiana/`
- File format: `.yianazip` packages
- Includes PDF + metadata

**Sync Status**:
- **Cloud icon**: Document in iCloud, not local
- **Checkmark**: Downloaded locally
- **Downloading**: Sync in progress

### Download Management

**Download All**:
1. Tap download icon (cloud with arrow)
2. All documents download to device
3. Use when going offline

**Storage**:
- Documents take space on both device and iCloud
- Delete from any device to free space
- Deletions sync across devices

### Offline Access

**Offline capabilities**:
- View downloaded documents
- Create new documents
- Scan new pages
- Edit titles
- Search (uses local index)

**Requires connection**:
- Downloading cloud documents
- Server OCR processing (on-device OCR works offline)

---

## Import and Export

### Importing PDFs

#### iOS/iPadOS Import

**From Files app**:
1. Open Files app
2. Long press PDF
3. Share > "Copy to Yiana"
4. Choose:
   - **New Document**: Creates new `.yianazip`
   - **Append to Existing**: Adds pages to selected document

**From Share Sheet**:
1. In any app with PDF
2. Tap Share
3. Choose "Yiana"
4. Select import option

#### macOS Import

**Drag and Drop**:
- Drag one or more PDFs into the Yiana window
- For multiple files, the bulk import UI appears with progress tracking

**File > Import**:
- Opens a file picker (up to 100 files)
- Launches bulk import view

**Import from Folder**:
- Select a folder to scan for all PDFs
- Bulk import with duplicate detection

**Bulk Import Features** (macOS):
- SHA256 duplicate detection against existing library
- Per-file timeout protection (30 seconds)
- Progress display with current file and count
- Pauses every 25 files to prevent overload
- Results summary showing successes, failures, and skipped duplicates

### Exporting Documents

#### Export as PDF

1. Open document
2. Tap share icon
3. Choose share method:
   - **Mail**: Attach to email
   - **Messages**: Send via iMessage
   - **Files**: Save to location
   - **Print**: Print document
   - **Other apps**: Any PDF-capable app

#### Bulk Export (macOS)

1. Use Cmd+Shift+E or File > Export All Documents as PDFs
2. Browse and select documents or folders
3. Choose destination folder
4. Export preserves folder structure

#### Export Options

**What's included**:
- All scanned pages
- Finalized text pages (as PDF)
- Original quality maintained
- Metadata (titles, dates) is NOT included in exported PDF

**File naming**:
- Uses document title
- Format: `Title.pdf`
- Special characters removed

---

## Print

### macOS

- **Cmd+P** to print the current document
- **Toolbar print button** in the document view
- Uses native macOS print dialog with page range, copies, and printer selection

### iOS/iPadOS

- Open the share sheet and select "Print"
- Standard iOS print dialog with AirPrint support

---

## Drag and Drop

### macOS

**Import PDFs from Finder**:
- Drag PDF files from Finder, Mail, or other apps into the Yiana window
- Multiple files trigger the bulk import flow

**Move documents between folders**:
- Drag a document row onto a folder row
- Visual highlight shows the target folder
- Release to move

### iOS/iPadOS (iPad)

**Move documents to folders**:
- Drag document from the main list to a sidebar folder
- Works in the sidebar area only (not within the main list, due to UITableView limitations)

**Page reordering**:
- In the page grid, drag pages to reorder

---

## Duplicate Scanner

*macOS only*

Find and remove duplicate documents in your library.

### How It Works

1. Open the duplicate scanner from the menu
2. Scanner computes SHA256 hashes of all documents
3. Identical documents are grouped together
4. Review groups -- originals are marked with a star
5. Select duplicates to delete
6. Confirm deletion

### Features

- **SHA256-based detection** - Compares actual PDF content, not just filenames
- **Original identification** - Oldest document marked as original
- **Bulk selection** - "Select All Duplicates" for quick cleanup
- **Safe deletion** - Requires confirmation before removing files
- **Rescan** - Automatically rescans after deletion

---

## Address Extraction

Yiana can extract and display contact information (patients, GPs, specialists) from scanned documents.

### How It Works

- A backend service on the Mac mini processes OCR results
- Extracted addresses are saved as `.addresses/*.json` files and synced via iCloud
- The app displays extracted data in the document info panel

### Viewing Addresses

1. Open a document
2. Open the info panel (tap info button or swipe)
3. The "Addresses" tab shows extracted contacts

### Editing and Correcting

- Tap any field to edit inline (name, address, phone, etc.)
- Corrections are saved as overrides without changing the original extraction
- Mark a contact as "prime" to designate the primary contact

### Address Type Settings

In Settings > Address Types, you can:
- Load predefined templates
- Create custom address types with names, icons, and colors
- Import/export address type configurations as JSON

For developer documentation on the backend extraction pipeline and how to adapt it for other domains, see [Address Extraction Backend Guide](../dev/AddressExtraction.md).

---

## Settings

Access settings from the gear icon or app menu.

### Paper Size
Choose between A4 (210mm x 297mm) and US Letter (8.5" x 11"). Affects rendered text pages and new scans. Default: A4.

### Sidebar Position (iPad)
Choose left or right placement for the document sidebar. Default: Right.

### Thumbnail Size (iPad)
Choose Small, Medium, or Large thumbnails for the page grid. Default: Medium.

### Developer Mode
Tap the version number 7 times to enable developer mode (session-based, resets on app restart). Provides access to:
- Search index reset and stats
- OCR tools (force re-run, clear cache)
- Debug information (bundle ID, paths, build type)
- Data deletion (with multi-step confirmation)

---

## Keyboard Shortcuts

### Document List

| Shortcut | Action |
|----------|--------|
| Cmd+N | New document |
| Cmd+F | Focus search |
| Cmd+Shift+F | New folder |
| Cmd+Shift+I | Import PDFs (macOS) |
| Delete | Delete selected document |

### Document View

| Shortcut | Action |
|----------|--------|
| Left arrow | Previous page |
| Right arrow | Next page |
| Space | Next page |
| Shift+Space | Previous page |
| Cmd+P | Print (macOS) |
| Cmd+S | Save |
| Cmd+E | Export |
| Cmd+W | Close document |
| Esc | Close document |

### Page Management

| Shortcut | Action |
|----------|--------|
| Cmd+C | Copy selected pages |
| Cmd+X | Cut selected pages |
| Cmd+V | Paste pages |
| Shift+Cmd+Z | Restore cut pages |

### Text Editor

| Shortcut | Action |
|----------|--------|
| Cmd+B | Bold |
| Cmd+I | Italic |
| Cmd+Shift+L | Toggle preview |
| Cmd+Return | Done (save) |
| Esc | Discard |

---

## Data Format

### File Storage

**Format**: `.yianazip` package (ZIP archive)
**Structure**:
```
document.yianazip
├── metadata.json (document info)
├── content.pdf (PDF content)
└── format.json (format version)
```

**Location**: `iCloud Drive/Yiana/Documents/`

### Metadata Structure

```json
{
  "id": "UUID",
  "title": "Document Title",
  "created": "2026-02-25T12:00:00Z",
  "modified": "2026-02-25T14:30:00Z",
  "pageCount": 5,
  "tags": [],
  "ocrCompleted": true,
  "hasPendingTextPage": false,
  "pdfHash": "sha256...",
  "ocrSource": "onDevice",
  "ocrConfidence": 0.95
}
```

### OCR Results

**Location**: `.ocr_results/` (alongside document)
**Format**: JSON with page-by-page text
**Processing**: On-device (immediate) and Mac mini server (background)

---

## Limitations and Design Decisions

### By Design

**Read-only PDF viewing**:
- No complex annotation model
- Simpler, faster performance
- Markup via PencilKit (macOS only)

**Text pages permanent**:
- "Pen and paper" philosophy
- Once finalized, cannot edit
- Create new text page to add more

**1-based page numbering**:
- Pages numbered 1, 2, 3... (not 0, 1, 2...)
- Matches human expectation
- Consistent throughout UI

### Current Limitations

**Platform limitations**:
- No camera scanning on macOS (hardware limitation)
- Bulk import/export and duplicate scanner are macOS only
- Drag-and-drop import is macOS only (iOS drag works for moving between folders on iPad)

**Feature limitations**:
- Tags exist as metadata but cannot be added or edited through the UI
- No tables or code blocks in text page markdown
- No inline images in text pages

---

## Privacy and Security

### Data Storage

**Local-first**:
- Documents stored on your device
- iCloud sync optional (but recommended)
- No third-party servers

**No tracking**:
- No analytics or telemetry
- No user behavior tracking
- No ads

### OCR Processing

**On-device** (default):
- All processing happens locally on your device
- No data leaves your device
- Works completely offline

**Server-based** (optional):
- Runs on your own Mac mini hardware
- Documents processed via iCloud sync
- No cloud services involved
- Complete control over data

### Address Extraction

- Runs on your Mac mini (not a cloud service)
- Results synced via your iCloud account
- User corrections stored locally alongside extracted data

---

## Accessibility

### VoiceOver Support

- All controls labeled
- Document content readable
- Search results announced
- Page navigation supported

### Display Accommodations

- **Dynamic Type**: Text scales with system settings
- **Dark Mode**: Full support
- **Reduce Motion**: Respects system setting
- **High Contrast**: Compatible

---

*Last updated: February 2026*
