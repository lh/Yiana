# Yiana Frequently Asked Questions (FAQ)

Common questions and answers about using Yiana.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Document Scanning](#document-scanning)
- [Text Pages](#text-pages)
- [Search & OCR](#search--ocr)
- [Organization](#organization)
- [Sync & Storage](#sync--storage)
- [Import & Export](#import--export)
- [Troubleshooting](#troubleshooting)
- [Privacy & Security](#privacy--security)

---

## Getting Started

### What is Yiana?

Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS. It lets you:
- Scan documents with your device camera
- Create typed text pages
- Search across all your documents
- Organize with folders
- Sync via iCloud

### Is Yiana free?

Pricing details coming soon. Currently in development/beta.

### What devices are supported?

- **iOS**: iPhone running iOS 17+
- **iPadOS**: iPad running iPadOS 17+
- **macOS**: Mac running macOS 14+ (Sonoma)

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
- Import PDFs from other sources
- Use a connected scanner (coming soon)

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
- **Doc** (center, gray circle): Black & white for text documents, receipts - optimized for clarity (default position)
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

No. Once you exit the note, text pages become permanent PDFs (like pen and paper). This is intentional!

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

But you don't need to know markdown - use the toolbar buttons!

### Where do text pages appear?

Text pages always append to the end of your document initially. After they're finalized (when you exit the note), they become regular PDF pages that you can reorder like any other page.

---

## Search & OCR

### What is OCR?

OCR (Optical Character Recognition) extracts text from scanned images. This makes your scanned documents searchable.

### How long does OCR take?

Typically a few minutes, depending on:
- Number of pages
- Image complexity
- Server availability

OCR happens automatically in the background.

### Why aren't my scanned documents searchable?

Possible reasons:
1. **OCR not complete yet** - Wait a few minutes
2. **No OCR server configured** - Requires Mac mini setup
3. **Document is handwritten** - OCR works best on printed text
4. **Image quality poor** - Rescan with better lighting

### Can I search PDF files I imported?

Yes, if the PDF already contains text (searchable PDF). If it's just images, it needs OCR processing.

### Does search work offline?

Yes! Search uses locally stored OCR results. No internet connection needed.

### Can I search multiple documents at once?

Yes - search from the document list searches across ALL documents.

---

## Organization

### How many folders can I create?

No limit. Create as many folders as you need.

### Can I nest folders?

Yes! Create folders within folders for hierarchical organization.

### Can I put a document in multiple folders?

No. Each document lives in one location. Use search or tags (coming soon) for multiple categorizations.

### How do I move a document between folders?

**Method 1**: Long press → Move → Select folder
**Method 2** (iPad): Long press → Drag to folder

### Can I rename folders?

Not yet - coming in a future update. Current workaround:
1. Create new folder with desired name
2. Move documents to new folder
3. Delete old folder

### What happens if I delete a folder?

You'll be prompted to:
- **Delete folder and contents** - Removes everything permanently
- **Delete folder only** - Moves documents to parent folder
- **Cancel** - No action taken

---

## Sync & Storage

### How does iCloud sync work?

Documents automatically sync when:
- You're signed into iCloud
- iCloud Drive is enabled
- You have internet connection

Changes propagate to all devices typically within seconds.

### Why isn't my document syncing?

Check:
1. **iCloud signed in** - Settings → [Your Name]
2. **iCloud Drive enabled** - Settings → iCloud → iCloud Drive
3. **Yiana allowed** - Settings → iCloud → iCloud Drive → Yiana (on)
4. **Internet connection** - Wi-Fi or cellular
5. **Storage space** - Enough iCloud storage available

### Can I use Yiana without iCloud?

Yes, but documents will be device-only. Not recommended unless you have a specific reason.

### How much iCloud storage do I need?

Depends on document volume:
- **Scanned page**: ~200 KB - 1 MB
- **Text page**: ~50-100 KB
- **100 documents** (~5 pages each): ~100-500 MB

Monitor your iCloud storage in Settings → iCloud.

### What happens if I run out of iCloud storage?

- Existing documents still accessible
- New documents won't sync
- You'll see warning messages
- Options: Delete documents or upgrade iCloud storage

### Can I back up documents locally?

Not built-in currently. Workarounds:
- Export documents as PDFs
- Copy `.yianazip` files from iCloud Drive folder manually
- Built-in backup system coming soon

---

## Import & Export

### What file formats can I import?

Currently: **PDF only**

Coming soon: JPEG, PNG, HEIC (will convert to PDF)

### How do I import a PDF from email?

1. Open email
2. Long press PDF attachment
3. Share → "Copy to Yiana"
4. Choose "New Document" or "Append to Existing"

### Can I export to formats other than PDF?

No. Documents export as PDF only. This preserves:
- Original quality
- Page layout
- Text integrity

### Does exported PDF include metadata?

No. Exported PDF is just the pages. Metadata (title, creation date, tags) stays in Yiana.

To preserve metadata: Keep the document in Yiana!

### Can I print documents?

Yes!
1. Open document
2. Tap share icon
3. Choose "Print"
4. Select printer
5. Print

---

## Troubleshooting

### App crashes when I scan

Try:
1. **Restart app** - Force quit and reopen
2. **Update iOS** - Settings → General → Software Update
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
5. **Check permissions** - Settings → Yiana → Camera (allow)

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
2. **OCR complete** - Wait for processing
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

## Privacy & Security

### Where are my documents stored?

- **Local**: On your device (encrypted by iOS/macOS)
- **iCloud**: In your private iCloud Drive (encrypted in transit and at rest)
- **Nowhere else**: No third-party servers

### Does Yiana track my usage?

No. Yiana has:
- ❌ No analytics
- ❌ No telemetry
- ❌ No user tracking
- ❌ No ads

### Can anyone else see my documents?

No, unless:
- You share them explicitly via export
- Someone has access to your iCloud account
- Someone has physical access to unlocked device

Documents are private by default.

### What about OCR processing?

OCR requires a server (your Mac mini). During processing:
- Documents uploaded temporarily
- Text extracted
- Results returned
- Original deleted from server

This is your own hardware, not a cloud service.

### Can I use Yiana offline?

Yes! Works offline for:
- Viewing downloaded documents
- Creating new documents
- Scanning new pages
- Searching (using cached OCR)

Requires connection for:
- Initial sync
- Downloading cloud documents
- OCR processing

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
- See [Troubleshooting Guide](Troubleshooting.md)

### Found a bug?

Please report issues on GitHub: [github.com/lh/Yiana/issues](https://github.com/lh/Yiana/issues)

### Feature request?

We'd love to hear your ideas! Submit requests on GitHub.

---

*Last updated: October 2025*
