# Yiana Frequently Asked Questions (FAQ)

Common questions and answers about using Yiana.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Document Scanning](#document-scanning)
- [Text Pages](#text-pages)
- [Search and OCR](#search-and-ocr)
- [Organization](#organization)
- [Sync and Storage](#sync-and-storage)
- [Import and Export](#import-and-export)
- [Printing](#printing)
- [Address Extraction](#address-extraction)
- [Troubleshooting](#troubleshooting)
- [Privacy and Security](#privacy-and-security)

---

## Getting Started

### What is Yiana?

Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS. It lets you:
- Scan documents with your device camera
- Create typed text pages
- Search across all your documents (with on-device and server OCR)
- Organize with folders
- Import and export PDFs (including bulk operations on macOS)
- Copy/cut/paste pages between documents
- Print documents
- View extracted address data
- Sync via iCloud

### Is Yiana free?

Pricing details coming soon. Currently in development/beta.

### What devices are supported?

- **iOS**: iPhone running iOS 18+
- **iPadOS**: iPad running iPadOS 18+
- **macOS**: Mac running macOS 15+ (Sequoia)

### Do I need iCloud?

iCloud is optional but strongly recommended for:
- Automatic sync across devices
- Backup protection
- Access from all your devices

You can use Yiana without iCloud, but documents will only be on one device.

---

## Document Scanning

### Why can't I scan on macOS?

Macs don't have built-in cameras suitable for document scanning. You can:
- Scan on iPhone/iPad, sync via iCloud
- Import existing PDFs (drag-and-drop, File > Import, or Import from Folder)

### How do I scan multi-page documents?

1. Tap a scan button to open the camera
2. Camera automatically detects and captures the first page
3. Review and tap "Save"
4. Document opens automatically
5. Tap scan button again to add more pages
6. Camera automatically captures each page
7. Repeat for all pages

Pages append in order. The camera uses VisionKit which automatically detects documents - no manual shutter button needed.

### Can I scan from photos I already took?

Not directly. The camera scanner requires real-time capture for:
- Auto edge detection
- Perspective correction
- Quality enhancement

**Workaround**: Convert photo to PDF first, then import.

### What's the difference between "Scan" and "Doc" buttons?

Three buttons appear at the bottom:
- **Scan** (left, colorful circle): Color scanning for photos, forms, colorful documents
- **Doc** (center, gray circle): Black and white for text documents, receipts - optimized for clarity (default position)
- **Text** (right): Create text page

### How do I retake a bad scan?

Before saving:
1. Review the scan preview
2. Tap "Retake" if needed
3. Re-scan the page

After saving:
1. Swipe up to view all pages
2. Long press bad page
3. Delete it
4. Scan replacement page

---

## Text Pages

### What are text pages?

Text pages let you type notes that become permanent PDF pages in your document. Think of them as typed notes that get "inked" onto the page when you're done.

### Can I edit a text page after saving?

No. Once you exit the note, text pages become permanent PDFs (like pen and paper). This is intentional.

If you need to add more information:
- Create a new text page
- Or create a new document version

### Why does the text button say "Resume"?

You have a draft text page in progress. Tapping "Resume" returns to the editor so you can finish it.

### Can I add images to text pages?

Not currently. Text pages support:
- Text with markdown formatting
- Headers (3 levels)
- Bold and italic
- Lists (bulleted and numbered)
- Blockquotes
- Horizontal dividers

Images must be scanned pages.

### What is markdown?

Markdown is a simple way to format text using symbols:
- `**bold**` becomes **bold**
- `*italic*` becomes *italic*
- `# Heading` becomes a header

But you don't need to know markdown - use the toolbar buttons.

### Where do text pages appear?

Text pages always append to the end of your document initially. After they're finalized (when you exit the note), they become regular PDF pages that you can reorder like any other page.

---

## Search and OCR

### What is OCR?

OCR (Optical Character Recognition) extracts text from scanned images. This makes your scanned documents searchable.

### How does OCR work in Yiana?

Yiana has two OCR systems:

1. **On-device OCR** - Uses Apple's Vision framework. Runs automatically when you scan or open a document. Results available within seconds. Works offline.
2. **Server OCR** - Runs on a Mac mini server (if configured). Processes documents in the background with higher accuracy for complex layouts.

Both feed into the same search index.

### Why aren't my scanned documents searchable?

Possible reasons:
1. **Just scanned** - On-device OCR runs automatically but may take a few seconds
2. **Poor image quality** - Rescan with better lighting
3. **Handwritten text** - OCR works best on printed text
4. **Server not configured** - On-device OCR handles most cases, but server OCR may produce better results

### Can I search PDF files I imported?

Yes, if the PDF already contains text (searchable PDF). If it's just images, on-device OCR will process it when you open the document.

### Does search work offline?

Yes. Search uses a local GRDB/FTS5 index on your device. No internet connection needed. On-device OCR also works offline.

### Can I search multiple documents at once?

Yes - search from the document list searches across ALL documents.

---

## Organization

### How many folders can I create?

No limit. Create as many folders as you need.

### Can I nest folders?

Yes. Create folders within folders for hierarchical organization.

### Can I put a document in multiple folders?

No. Each document lives in one location. Use search for finding documents across folders.

### How do I move a document between folders?

**Method 1**: Long press > Move > Select folder
**Method 2** (macOS): Drag document onto a folder
**Method 3** (iPad): Drag document to a sidebar folder

### Can I rename folders?

Yes. Right-click (macOS) or long press (iOS) a folder and select "Rename". Enter the new name and confirm.

### What happens if I delete a folder?

You'll be prompted to:
- **Delete folder and contents** - Removes everything permanently
- **Delete folder only** - Moves documents to parent folder
- **Cancel** - No action taken

---

## Sync and Storage

### How does iCloud sync work?

Documents automatically sync when:
- You're signed into iCloud
- iCloud Drive is enabled
- You have internet connection

Changes propagate to all devices typically within seconds.

### Why isn't my document syncing?

Check:
1. **iCloud signed in** - Settings > [Your Name]
2. **iCloud Drive enabled** - Settings > iCloud > iCloud Drive
3. **Yiana allowed** - Settings > iCloud > iCloud Drive > Yiana (on)
4. **Internet connection** - Wi-Fi or cellular
5. **Storage space** - Enough iCloud storage available

### Can I use Yiana without iCloud?

Yes, but documents will be device-only. Not recommended unless you have a specific reason.

### How much iCloud storage do I need?

Depends on document volume:
- **Scanned page**: ~200 KB - 1 MB
- **Text page**: ~50-100 KB
- **100 documents** (~5 pages each): ~100-500 MB

Monitor your iCloud storage in Settings > iCloud.

### What happens if I run out of iCloud storage?

- Existing documents still accessible
- New documents won't sync
- You'll see warning messages
- Options: Delete documents or upgrade iCloud storage

### Can I back up documents locally?

Yes. On macOS, use Cmd+Shift+E (or File > Export All Documents as PDFs) to bulk export your library. The export preserves your folder structure. You can also manually copy `.yianazip` files from the iCloud Drive folder.

---

## Import and Export

### What file formats can I import?

Currently: **PDF only**

### How do I import a PDF from email?

1. Open email
2. Long press PDF attachment
3. Share > "Copy to Yiana"
4. Choose "New Document" or "Append to Existing"

### How do I import many PDFs at once? (macOS)

Three options:
1. **Drag and drop** - Drag multiple PDFs from Finder into the Yiana window
2. **File > Import** - Select up to 100 files at once
3. **Import from Folder** - Select a folder and import all PDFs in it

The bulk import system detects duplicates (via SHA256 hash), shows progress, and reports results.

### Can I export to formats other than PDF?

No. Documents export as PDF only. This preserves:
- Original quality
- Page layout
- Text integrity

### Does exported PDF include metadata?

No. Exported PDF is just the pages. Metadata (title, creation date) stays in Yiana.

---

## Printing

### Can I print documents?

Yes.

**macOS**: Press Cmd+P or click the print button in the toolbar. The native macOS print dialog appears with page range, copies, and printer selection.

**iOS/iPadOS**: Open the document, tap the share icon, and select "Print" from the share sheet.

---

## Address Extraction

### What is address extraction?

A backend service on the Mac mini extracts contact information (patients, GPs, opticians, specialists) from your scanned documents. Results appear in the document info panel.

### How do I view extracted addresses?

Open a document and go to the info panel. The "Addresses" tab shows any extracted contacts with their details.

### Can I correct extraction errors?

Yes. Tap any field to edit it inline. Corrections are saved as overrides without changing the original extraction data.

### Do I need a Mac mini for this?

The extraction runs on a Mac mini server. Without it, no addresses are extracted. However, the rest of Yiana works normally without it.

### Can I adapt this for a different type of document?

Yes. The extraction pipeline is designed to be domain-adaptable. See the [Address Extraction Backend Guide](../dev/AddressExtraction.md) for detailed instructions and LLM prompts for adapting the system to other domains (e.g., customers and suppliers, legal documents, real estate).

---

## Troubleshooting

### App crashes when I scan

Try:
1. **Restart app** - Force quit and reopen
2. **Update iOS** - Settings > General > Software Update
3. **Free up storage** - Delete old photos/apps
4. **Restart device** - Power off and on
5. **Reinstall app** - Delete and reinstall Yiana

If problem persists, please report the issue.

### Camera won't focus during scanning

Tips:
1. **Clean camera lens**
2. **Improve lighting** - Use natural light if possible
3. **Hold steady** - Rest device on surface if shaky
4. **Increase distance** - Move camera farther from document
5. **Check permissions** - Settings > Yiana > Camera (allow)

### Text page preview won't show

The preview requires:
- Sufficient memory (close other apps)
- Valid markdown syntax (check for errors)
- Renderer running (wait a moment)

Try:
- Tap "Preview" button again
- Close and reopen editor
- Restart app if needed

### Search not finding documents

Verify:
1. **Document title correct** - Check spelling
2. **OCR complete** - Open the document to trigger on-device OCR if needed
3. **Search term in document** - Double-check content
4. **Case-insensitive** - Try different capitalization

### Swipe-up gesture not working

The gesture only works when:
- Page is at "fit to screen" zoom
- Not zoomed in or out
- Document has more than 1 page

Try: Double-tap to fit screen, then swipe up.

### Document won't open

Possible causes:
1. **Not downloaded** - Tap cloud icon to download
2. **Sync in progress** - Wait for completion
3. **Corrupted file** - May need to restore from backup
4. **Storage full** - Free up space

### Pages appear in wrong order

You may have accidentally reordered. To fix:
1. Swipe up to view all pages
2. Long press and drag pages to correct order
3. Swipe down to exit

Changes save automatically.

---

## Privacy and Security

### Where are my documents stored?

- **Local**: On your device (encrypted by iOS/macOS)
- **iCloud**: In your private iCloud Drive (encrypted in transit and at rest)
- **Nowhere else**: No third-party servers

### Does Yiana track my usage?

No. Yiana has:
- No analytics
- No telemetry
- No user tracking
- No ads

### Can anyone else see my documents?

No, unless:
- You share them explicitly via export
- Someone has access to your iCloud account
- Someone has physical access to unlocked device

Documents are private by default.

### What about OCR processing?

**On-device OCR**: Everything stays on your device. No data leaves.

**Server OCR** (if configured): Documents are processed on your own Mac mini hardware via iCloud sync. This is your own hardware, not a cloud service.

### Can I use Yiana offline?

Yes. Works offline for:
- Viewing downloaded documents
- Creating new documents
- Scanning new pages
- Searching (using local index)
- On-device OCR

Requires connection for:
- Initial sync
- Downloading cloud documents
- Server OCR processing
- Address extraction processing

### Is my data encrypted?

Yes:
- **On device**: iOS/macOS encryption
- **In iCloud**: Encrypted in transit and at rest
- **During sync**: TLS encryption

### What happens to deleted documents?

Deleted documents:
1. Removed from all devices (sync)
2. Moved to iCloud "Recently Deleted" (30 days)
3. Permanently deleted after 30 days

Recover within 30 days via iCloud Drive.

---

## Still Have Questions?

### Can't find your answer?

- Check the [User Guide](GettingStarted.md)
- Read the [Features Overview](Features.md)

### Found a bug?

Please report issues on GitHub: [github.com/lh/Yiana/issues](https://github.com/lh/Yiana/issues)

### Feature request?

We'd love to hear your ideas. Submit requests on GitHub.

---

*Last updated: February 2026*
