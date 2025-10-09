# Yiana Features Overview

**Yiana** is a document scanning and PDF management app for iOS, iPadOS, and macOS. This guide covers all features in detail.

---

## Table of Contents

- [Document Scanning](#document-scanning)
- [Text Pages](#text-pages)
- [Document Organization](#document-organization)
- [Search](#search)
- [Page Management](#page-management)
- [Navigation & Gestures](#navigation--gestures)
- [iCloud Sync](#icloud-sync)
- [Import & Export](#import--export)
- [Platform Features](#platform-features)

---

## Document Scanning

### Camera Scanning (iOS & iPadOS)

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
- Output: Black & white PDF
- Auto-enhancement: Optimized for text clarity
- Auto-crop: Yes

**"Text"** (right) - Create text page

#### Scanning Tips

✅ **Best Practices**:
- Use good lighting (natural light is best)
- Place document on contrasting background
- Hold camera steady
- Ensure all corners are visible
- Review each scan before saving

✅ **Multi-Page Scanning**:
- Camera automatically detects and captures documents
- Review and tap "Save" or "Retake"
- Tap scan button again to add more pages
- Pages append in order

✅ **Automatic Scan Quality**:
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

🔒 **"Pen and Paper" Philosophy**:
- Text pages are **drafts** while editing
- Become **permanent PDF pages** when you exit the note
- Cannot be edited after exiting (by design)
- Can create new text page if you need to add more

📍 **Page Position**:
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

#### Moving Documents

**Method 1** (drag & drop - iPad):
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
- **Tags**: For categorization (coming soon)
- **OCR status**: Whether text extraction is complete

---

## Search

Powerful full-text search across all documents.

### What Gets Searched

✅ **Document titles**
✅ **Scanned text** (via OCR)
✅ **Text pages** (typed content)
❌ **Folder names** (not currently)

### Search Features

#### Real-Time Results
- Results appear as you type
- Sorted by relevance
- Title matches ranked higher

#### Search Highlighting
- Search terms highlighted in snippets
- Jump directly to matching page
- Context shown around matches

#### Search Icons

🔍 **Magnifying glass** = Content match (in scanned text)
📄 **Document icon** = Title match
🔵 **Blue tint** = Both title and content match

### Search Tips

💡 **Be specific**:
- "receipt october" better than just "receipt"
- Include dates, amounts, vendor names

💡 **Case insensitive**:
- "coffee", "Coffee", "COFFEE" all match

💡 **Partial matches**:
- "oct" matches "October"
- "star" matches "Starbucks"

### OCR Processing

📸 **Automatic OCR**:
- Scanned documents processed automatically
- OCR runs on Mac mini server (if configured)
- Text extraction happens in background
- No user action needed

⏱️ **Processing Time**:
- Typically completes within minutes
- Larger documents take longer
- Search available after OCR completes

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

⚠️ **Warning**: Page deletion is permanent!

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

## Navigation & Gestures

### Swipe Gestures

**While viewing a document**:

| Gesture | Action |
|---------|--------|
| Swipe left | Next page |
| Swipe right | Previous page |
| Swipe up | View page grid |
| Swipe down | Document info (coming soon) |

**Important**: Swipe up/down only work when page is at fit-to-screen zoom (not zoomed in).

### Zoom Gestures

| Gesture | Action |
|---------|--------|
| Pinch out | Zoom in |
| Pinch in | Zoom out |
| Double-tap | Fit to screen |
| Two-finger tap | Zoom to fit width |

### Button Controls

**Document view**:
- **← Back arrow**: Return to document list
- **Title**: Tap to edit
- **✏️ Markup**: Annotate PDF (macOS only)
- **⎙ Export**: Share as PDF

**Bottom toolbar** (left to right):
- **📸 Scan**: Color scan
- **📄 Doc**: B&W document scan (center - default position)
- **📝 Text**: Create text page

---

## iCloud Sync

Documents automatically sync across your Apple devices.

### How It Works

📱 **Automatic**:
- Documents save to iCloud Documents
- Sync happens in background
- No manual action needed

☁️ **Cloud Container**:
- Location: `iCloud Drive/Yiana/`
- File format: `.yianazip` packages
- Includes PDF + metadata

🔄 **Sync Status**:
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

✅ **Offline capabilities**:
- View downloaded documents
- Create new documents
- Scan new pages
- Edit titles

❌ **Requires connection**:
- Initial document list load
- Downloading cloud documents
- OCR processing (server-based)

---

## Import & Export

### Importing PDFs

#### iOS/iPadOS Import

**From Files app**:
1. Open Files app
2. Long press PDF
3. Share → "Copy to Yiana"
4. Choose:
   - **New Document**: Creates new `.yianazip`
   - **Append to Existing**: Adds pages to selected document

**From Share Sheet**:
1. In any app with PDF
2. Tap Share
3. Choose "Yiana"
4. Select import option

#### macOS Import

**Drag & Drop** (coming soon):
- Drag PDF into Yiana window
- Choose import option

**File → Import** (coming soon):
- Choose PDF from file picker
- Select destination

### Exporting Documents

#### Export as PDF

1. Open document
2. Tap share icon (⎙)
3. Choose share method:
   - **Mail**: Attach to email
   - **Messages**: Send via iMessage
   - **Files**: Save to location
   - **Print**: Print document
   - **Other apps**: Any PDF-capable app

#### Export Options

**What's included**:
- ✅ All scanned pages
- ✅ Finalized text pages (as PDF)
- ✅ Original quality maintained
- ❌ Metadata (titles, dates) - PDF only

**File naming**:
- Uses document title
- Format: `Title.pdf`
- Special characters removed

---

## Platform Features

### iOS & iPadOS

✅ **Camera scanning**
✅ **Document scanner (VisionKit)**
✅ **Touch gestures**
✅ **Split View multitasking** (iPad)
✅ **Slide Over** (iPad)
✅ **Dark mode**

❌ **PDF markup** (planned)

### macOS

✅ **Keyboard navigation**
✅ **Menu bar commands**
✅ **Window management**
✅ **PDF markup** (PencilKit)
✅ **Dark mode**

❌ **Camera scanning** (no camera)

### Platform-Specific Gestures

#### iPad Split View
- **Drag from top**: Enable split view
- **Adjust divider**: Resize panes
- **Text editor + preview**: Side-by-side editing

#### macOS Trackpad
- **Two-finger swipe**: Navigate pages
- **Pinch**: Zoom
- **Double-tap**: Fit to screen

---

## Keyboard Shortcuts

### Document List

| Shortcut | Action |
|----------|--------|
| `⌘N` | New document |
| `⌘F` | Focus search |
| `⌘⇧F` | New folder |
| `⌘⇧I` | Import PDFs (macOS) |
| `Delete` | Delete selected document |

### Document View

| Shortcut | Action |
|----------|--------|
| `←` | Previous page |
| `→` | Next page |
| `Space` | Next page |
| `Shift+Space` | Previous page |
| `⌘S` | Save |
| `⌘E` | Export |
| `⌘W` | Close document |
| `Esc` | Close document |

### Text Editor

| Shortcut | Action |
|----------|--------|
| `⌘B` | Bold |
| `⌘I` | Italic |
| `⌘⇧L` | Toggle preview |
| `⌘Return` | Done (save) |
| `Esc` | Discard |

---

## Data Format

### File Storage

**Format**: `.yianazip` package
**Structure**:
```
document.yianazip
├── metadata.json (document info)
└── data.pdf (PDF content)
```

**Location**: `iCloud Drive/Yiana/Documents/`

### Metadata Structure

```json
{
  "id": "UUID",
  "title": "Document Title",
  "created": "2025-10-07T12:00:00Z",
  "modified": "2025-10-07T14:30:00Z",
  "pageCount": 5,
  "tags": [],
  "ocrCompleted": true,
  "hasPendingTextPage": false
}
```

### OCR Results

**Location**: `.ocr_results/` (alongside document)
**Format**: JSON with page-by-page text
**Processing**: Mac mini server (if configured)

---

## Limitations & Design Decisions

### By Design

🔒 **Read-only PDF viewing**:
- No complex annotation model
- Simpler, faster performance
- Markup via PencilKit (macOS only)

🔒 **Text pages permanent**:
- "Pen and paper" philosophy
- Once finalized, cannot edit
- Create new text page to add more

🔒 **1-based page numbering**:
- Pages numbered 1, 2, 3... (not 0, 1, 2...)
- Matches human expectation
- Consistent throughout UI

### Current Limitations

📋 **Planned features**:
- Tags for organization
- Document metadata editing
- Backup/restore system
- PDF annotation (iOS/iPadOS)
- Batch operations

🔧 **Platform limitations**:
- No camera scanning on macOS (hardware limitation)
- OCR requires server (processing intensive)

---

## Privacy & Security

### Data Storage

✅ **Local-first**:
- Documents stored on your device
- iCloud sync optional (but recommended)
- No third-party servers

✅ **No tracking**:
- No analytics or telemetry
- No user behavior tracking
- No ads

### OCR Processing

⚠️ **Server-based**:
- OCR runs on your Mac mini (if configured)
- Documents uploaded temporarily for processing
- Results returned and cached
- Original documents remain on device

🔒 **Privacy**:
- OCR server is your own hardware
- No cloud service involved
- Complete control over data

---

## Accessibility

### VoiceOver Support

✅ **Fully accessible**:
- All controls labeled
- Document content readable
- Search results announced
- Page navigation supported

### Display Accommodations

✅ **Dynamic Type**: Text scales with system settings
✅ **Dark Mode**: Full support
✅ **Reduce Motion**: Respects system setting
✅ **High Contrast**: Compatible

---

## Tips & Tricks

### Power User Tips

💡 **Quick document creation**:
- Use Siri Shortcuts to trigger scan
- Create from Camera roll
- Import from Files app

💡 **Search efficiency**:
- Use specific keywords
- Search by date range (e.g., "October 2025")
- Combine terms (e.g., "receipt starbucks")

💡 **Organization strategy**:
- Folders for categories (Tax, Medical, Work)
- Descriptive titles within folders
- Use search more than browsing

💡 **Text page workflow**:
- Create outline as text page first
- Attach scanned supporting documents
- Export complete package

### Common Workflows

**📧 Email Receipt Processing**:
1. Forward email with receipt to yourself
2. Open PDF attachment
3. Share → "Copy to Yiana"
4. Add text page with notes
5. Title with vendor and amount

**💼 Business Expense Tracking**:
1. Scan receipt immediately
2. Title: "Expense - [Vendor] - [Amount]"
3. Add text page with category
4. Create folder per month
5. Export all at month end

**🏥 Medical Records**:
1. Scan document
2. Title: "Medical - [Provider] - [Date]"
3. Text page with summary/notes
4. Tag with condition (coming soon)
5. Create folder per year

---

## What's Next?

### Coming Soon

- 📝 PDF annotation (iOS/iPadOS)
- 🏷️ Tags and advanced filtering
- 📊 Document metadata editing
- 💾 Backup/restore system
- 📤 Batch export options
- 🔍 Advanced search filters

### Request Features

Have ideas? Contribute to the project on GitHub!

---

*Last updated: October 2025*
