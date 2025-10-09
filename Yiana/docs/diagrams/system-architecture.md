# System Architecture Diagram

This diagram shows the overall system architecture of Yiana, including app components, services, and storage.

```mermaid
graph TB
    subgraph "iOS/iPadOS App"
        A1[YianaApp<br/>SwiftUI Entry Point]
        A2[DocumentListView]
        A3[DocumentEditView]
        A4[ScannerView]
        A5[TextPageEditorView]

        VM1[DocumentListViewModel]
        VM2[DocumentViewModel]
        VM3[TextPageEditorViewModel]

        S1[DocumentRepository]
        S2[ScanningService]
        S3[ImportService]
        S4[OCRProcessor]
        S5[TextPagePDFRenderer]
        S6[ProvisionalPageManager]

        M1[NoteDocument<br/>UIDocument]
        M2[DocumentMetadata]

        A1 --> A2
        A2 --> A3
        A3 --> A4
        A3 --> A5

        A2 --> VM1
        A3 --> VM2
        A5 --> VM3

        VM1 --> S1
        VM2 --> S1
        VM2 --> S2
        VM2 --> S3
        VM2 --> S6
        VM3 --> S5

        S1 --> M1
        M1 --> M2
    end

    subgraph "macOS App"
        MA1[YianaApp<br/>SwiftUI Entry Point]
        MA2[DocumentListView]
        MA3[PDFViewer]

        MVM1[DocumentListViewModel]

        MS1[DocumentRepository]

        MM1[YianaDocument<br/>NSDocument]

        MA1 --> MA2
        MA2 --> MA3
        MA2 --> MVM1
        MVM1 --> MS1
        MS1 --> MM1
    end

    subgraph "iCloud Drive Storage"
        IC1[(iCloud.com.vitygas.Yiana/<br/>Documents/)]
        IC2[.yianazip files]
        IC3[.ocr_results/]

        IC1 --> IC2
        IC1 --> IC3
    end

    subgraph "OCR Service (Mac mini)"
        O1[YianaOCRService<br/>Swift CLI]
        O2[Directory Watcher]
        O3[OCR Processor<br/>Vision Framework]
        O4[Results Writer]

        O1 --> O2
        O2 --> O3
        O3 --> O4
    end

    M1 -.iCloud Sync.-> IC1
    MM1 -.iCloud Sync.-> IC1
    O2 -.Watch.-> IC1
    O4 -.Write.-> IC3
    S4 -.Read.-> IC3

    style A1 fill:#e1f5ff
    style MA1 fill:#fff4e1
    style O1 fill:#ffe1f5
    style IC1 fill:#e8f5e9
```

## Component Responsibilities

### iOS/iPadOS App
- **Views**: SwiftUI UI layer (DocumentListView, DocumentEditView, ScannerView, TextPageEditorView)
- **ViewModels**: State management and business logic (DocumentListViewModel, DocumentViewModel, TextPageEditorViewModel)
- **Services**: Core functionality (DocumentRepository, ScanningService, ImportService, OCRProcessor, TextPagePDFRenderer, ProvisionalPageManager)
- **Models**: Data structures (NoteDocument extends UIDocument, DocumentMetadata)

### macOS App
- **Views**: SwiftUI UI layer (DocumentListView, PDFViewer)
- **ViewModels**: State management (DocumentListViewModel)
- **Services**: Core functionality (DocumentRepository)
- **Models**: Data structures (YianaDocument extends NSDocument)

### iCloud Drive Storage
- **Documents**: `.yianazip` package files with embedded metadata + PDF
- **OCR Results**: `.ocr_results/` directory with JSON/XML/hOCR files

### OCR Service
- **Directory Watcher**: Monitors iCloud Drive for new/modified documents
- **OCR Processor**: Extracts text using Vision framework
- **Results Writer**: Saves OCR results to `.ocr_results/` directory

## Data Flow Patterns

1. **Document Creation**: YianaApp → DocumentRepository → NoteDocument/YianaDocument → iCloud Drive
2. **Scanning**: ScannerView → ScanningService → DocumentRepository → iCloud Sync
3. **OCR Processing**: iCloud Sync → OCR Service → Vision Framework → .ocr_results/ → iCloud Sync → OCRProcessor reads results
4. **Text Page Creation**: TextPageEditorView → TextPagePDFRenderer → ProvisionalPageManager → DocumentViewModel → DocumentRepository
5. **Search**: DocumentListViewModel → OCRProcessor (reads .ocr_results/) → Search results

## Platform Differences

- iOS/iPadOS uses UIDocument (NoteDocument)
- macOS uses NSDocument (YianaDocument)
- Both share DocumentMetadata format
- Both sync via iCloud Drive
- No shared protocols or cross-platform abstractions (platform-specific is preferred)
