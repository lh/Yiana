# Data Flow Diagrams

This document contains data flow diagrams for major operations in Yiana.

## Document Creation & Import Flow

```mermaid
sequenceDiagram
    participant U as User
    participant DLV as DocumentListView
    participant DLVM as DocumentListViewModel
    participant DR as DocumentRepository
    participant ND as NoteDocument
    participant IC as iCloud Drive

    U->>DLV: Tap "New Document"
    DLV->>DLV: Show title input sheet
    U->>DLV: Enter title
    DLV->>DLVM: createDocument(title)
    DLVM->>DR: createNewDocument(title)
    DR->>ND: init(fileURL)
    DR->>ND: updateMetadata(title, created, ...)
    DR->>ND: save()
    ND->>IC: Write .yianazip<br/>[metadata JSON][separator][empty PDF]
    IC-->>DLVM: Document created
    DLVM-->>DLV: Refresh list
    DLV-->>U: Show new document in list
```

## PDF Import Flow

```mermaid
sequenceDiagram
    participant U as User
    participant IS as ImportService
    participant DR as DocumentRepository
    participant ND as NoteDocument
    participant IC as iCloud Drive

    U->>IS: Share PDF to app
    IS->>IS: Check if new or append
    alt New Document
        IS->>DR: createNewDocument(title)
        DR->>ND: init(fileURL)
        DR->>ND: setPDFData(importedPDF)
        DR->>ND: setMetadata(ocrCompleted: false)
        DR->>ND: save()
    else Append to Existing
        IS->>DR: loadDocument(existingID)
        DR->>ND: open()
        ND->>IC: Read existing .yianazip
        DR->>ND: appendPDF(importedPDF)
        DR->>ND: setMetadata(ocrCompleted: false)
        DR->>ND: save()
    end
    ND->>IC: Write .yianazip
    IC-->>U: Document ready
```

## Scanning Flow

```mermaid
sequenceDiagram
    participant U as User
    participant DEV as DocumentEditView
    participant SV as ScannerView
    participant VK as VisionKit<br/>VNDocumentCameraViewController
    participant DVM as DocumentViewModel
    participant ND as NoteDocument
    participant IC as iCloud Drive

    U->>DEV: Tap scan button (Color/Doc/Text)
    DEV->>SV: show(mode: .color/.monochrome)
    SV->>VK: present()
    VK->>U: Camera interface
    U->>VK: Position document
    VK->>VK: Auto-detect edges
    VK->>VK: Auto-capture
    U->>VK: Tap "Save"
    VK->>SV: didFinish(scan)
    SV->>DVM: appendScannedPages(images, mode)
    DVM->>DVM: Convert images to PDF
    DVM->>ND: appendPDF(scannedPDF)
    DVM->>ND: setMetadata(ocrCompleted: false)
    DVM->>ND: save()
    ND->>IC: Write .yianazip
    IC-->>U: Scanned pages added
```

## Text Page Creation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant DEV as DocumentEditView
    participant TPEV as TextPageEditorView
    participant TPEVM as TextPageEditorViewModel
    participant TPR as TextPagePDFRenderer
    participant PPM as ProvisionalPageManager
    participant DVM as DocumentViewModel
    participant ND as NoteDocument

    U->>DEV: Tap "Text" scan button
    DEV->>TPEV: show()
    TPEV->>TPEVM: init()
    TPEVM->>TPEVM: loadDraftIfAvailable()
    U->>TPEV: Type markdown content
    TPEV->>TPEVM: content = newText
    TPEVM->>TPEVM: scheduleLiveRender()
    TPEVM->>TPR: render(markdown, options)
    TPR-->>TPEVM: renderedPageData (PDF)
    TPEVM->>DVM: setProvisionalPreviewData(renderedPageData)
    DVM->>PPM: updateProvisionalData(renderedPageData)
    DVM->>PPM: combinedData(using: pdfData)
    PPM-->>DVM: (combinedPDF, provisionalRange)
    DVM->>DVM: displayPDFData = combinedPDF
    DVM-->>U: Show preview in document view

    Note over U,TPEVM: User continues editing, live preview updates

    U->>TPEV: Tap "Done"
    TPEV->>TPEVM: flushDraftNow()
    DEV->>DEV: finalizeTextPageIfNeeded()
    DEV->>DVM: appendTextPage(markdown, cached PDF)
    DVM->>ND: appendPDF(cachedRenderedPage)
    DVM->>ND: setMetadata(fullText, ocrCompleted: false)
    DVM->>ND: save()
    DVM->>PPM: clearProvisionalData()
    DVM->>TPEVM: deleteDraft()
```

## Search Flow

```mermaid
sequenceDiagram
    participant U as User
    participant DLV as DocumentListView
    participant DLVM as DocumentListViewModel
    participant DR as DocumentRepository
    participant OCRP as OCRProcessor
    participant IC as iCloud Drive

    U->>DLV: Enter search term
    DLV->>DLVM: searchTerm = text
    DLVM->>DLVM: performSearch(term)

    loop For each document
        DLVM->>DR: getMetadata(docID)
        DR-->>DLVM: metadata (title, fullText, ocrCompleted)

        alt Title matches
            DLVM->>DLVM: Add SearchResult(title match, pageNumber: nil)
        end

        alt Has OCR and fullText matches
            DLVM->>OCRP: getOCRResultsPath(docID)
            OCRP->>IC: Read .ocr_results/[docID].json
            IC-->>OCRP: OCR JSON data
            OCRP-->>DLVM: OCR pages with text
            DLVM->>DLVM: Search each page's text
            DLVM->>DLVM: Add SearchResult(snippet, pageNumber: N)
        end
    end

    DLVM-->>DLV: searchResults
    DLV-->>U: Display results

    U->>DLV: Tap result
    DLV->>DLV: Navigate to document + page
```

## OCR Processing Flow (Backend Service)

```mermaid
sequenceDiagram
    participant IC as iCloud Drive
    participant DW as Directory Watcher<br/>(YianaOCRService)
    participant OCRP as OCR Processor
    participant VF as Vision Framework
    participant RW as Results Writer

    loop Monitor directory
        DW->>IC: Watch Documents/
        IC->>DW: File changed event
        DW->>IC: Read .yianazip metadata
        IC-->>DW: DocumentMetadata

        alt ocrCompleted == false
            DW->>IC: Read PDF data
            IC-->>DW: PDF bytes
            DW->>OCRP: process(pdfData)

            loop For each page
                OCRP->>VF: recognizeText(pageImage)
                VF-->>OCRP: textObservations
                OCRP->>OCRP: Build page JSON<br/>(pageNumber, text, textBlocks)
            end

            OCRP-->>DW: OCR results
            DW->>RW: writeResults(docID, results)
            RW->>IC: Write .ocr_results/[docID].json
            RW->>IC: Update .yianazip metadata<br/>(ocrCompleted: true, fullText)
        end
    end
```

## Provisional Page Composition Flow

```mermaid
sequenceDiagram
    participant TPEVM as TextPageEditorViewModel
    participant DVM as DocumentViewModel
    participant PPM as ProvisionalPageManager
    participant PDFKit as PDFKit

    TPEVM->>DVM: setProvisionalPreviewData(renderedPageData)
    DVM->>PPM: updateProvisionalData(renderedPageData)
    DVM->>PPM: combinedData(using: pdfData)

    PPM->>PPM: Calculate hashes<br/>(savedHash, provisionalHash)

    alt Cache hit
        PPM->>PPM: Hashes match cache
        PPM-->>DVM: Return cached (data, range)
    else Cache miss
        PPM->>PDFKit: PDFDocument(data: savedData)
        PDFKit-->>PPM: baseDocument
        PPM->>PDFKit: PDFDocument(data: provisionalData)
        PDFKit-->>PPM: draftDocument

        PPM->>PPM: combined = PDFDocument()

        loop For each page in baseDocument
            PPM->>PDFKit: combined.insert(page, at: index)
        end

        PPM->>PPM: startIndex = combined.pageCount

        loop For each page in draftDocument
            PPM->>PDFKit: combined.insert(page, at: index)
        end

        PPM->>PPM: endIndex = combined.pageCount
        PPM->>PDFKit: combined.dataRepresentation()
        PDFKit-->>PPM: combinedPDFData

        PPM->>PPM: Cache (data, range, hashes)
        PPM-->>DVM: Return (combinedPDFData, provisionalRange)
    end

    DVM->>DVM: displayPDFData = combinedData
    DVM->>DVM: provisionalPageRange = range
```

## Key Data Structures

### DocumentMetadata
```swift
struct DocumentMetadata: Codable {
    let id: UUID
    var title: String
    var created: Date
    var modified: Date
    var pageCount: Int
    var ocrCompleted: Bool
    var fullText: String?
}
```

### .yianazip Format
```
[metadata JSON bytes]
[0xFF 0xFF 0xFF 0xFF]  // 4-byte separator
[raw PDF bytes]
```

### OCR Results JSON
```json
{
  "pages": [
    {
      "pageNumber": 1,  // 1-based
      "text": "Full page text...",
      "textBlocks": [
        {
          "text": "Block text",
          "bounds": {"x": 0, "y": 0, "width": 100, "height": 20}
        }
      ]
    }
  ]
}
```
