# PDF Rendering Pipeline

This document describes the PDF rendering pipeline used throughout Yiana, including viewing, scanning, and text page creation.

## PDF Viewing Pipeline (Read-Only)

```mermaid
flowchart TB
    Start([User opens document])
    Start --> Load

    Load[DocumentViewModel loads NoteDocument]
    Load --> Extract

    Extract[Extract PDF data from .yianazip]
    Extract --> Create

    Create[Create PDFDocument from Data]
    Create --> Display

    Display[Pass to PDFView via PDFViewer]
    Display --> Render

    subgraph "PDFKit Rendering"
        Render[PDFView renders pages]
        Render --> Cache[PDFKit internal cache]
        Cache --> GPU[CoreGraphics GPU rendering]
    end

    GPU --> Screen[Display on screen]

    style Start fill:#e1f5ff
    style Screen fill:#c8e6c9
```

## Scanned Document to PDF Pipeline

```mermaid
flowchart TB
    Start([User captures document])
    Start --> VisionKit

    subgraph "VisionKit Processing"
        VisionKit[VNDocumentCameraViewController]
        VisionKit --> Detect[Auto-detect document edges]
        Detect --> Capture[Auto-capture when ready]
        Capture --> Perspective[Apply perspective correction]
        Perspective --> Filter[Apply filter<br/>Color/Monochrome]
    end

    Filter --> UIImage[Return UIImage array]
    UIImage --> Convert

    subgraph "App-Side Conversion"
        Convert[ScanningService converts to PDF]
        Convert --> Context[Create PDF graphics context]
        Context --> Loop{For each image}

        Loop --> Page[Begin new PDF page]
        Page --> Draw[Draw UIImage to page]
        Draw --> Loop

        Loop --> Complete[Complete PDF context]
    end

    Complete --> PDFData[Return PDF Data]
    PDFData --> Append

    subgraph "Document Integration"
        Append[DocumentViewModel appends to document]
        Append --> Combine[Combine existing + new PDF pages]
        Combine --> Save[Save to .yianazip]
    end

    Save --> End([Document updated])

    style Start fill:#e1f5ff
    style End fill:#c8e6c9
```

## Text Page Markdown to PDF Pipeline

```mermaid
flowchart TB
    Start([User types markdown])
    Start --> Schedule

    Schedule[TextPageEditorViewModel<br/>schedules render]
    Schedule --> Debounce[Debounce timer<br/>default 0.5s]
    Debounce --> Render

    subgraph "TextPagePDFRenderer Processing"
        Render[render markdown, options]
        Render --> Parse[Parse markdown to tokens]

        Parse --> Build[Build NSAttributedString]

        subgraph "Markdown Parsing"
            Build --> Headers[Parse headers H1/H2/H3]
            Headers --> Bold[Parse bold **text**]
            Bold --> Italic[Parse italic *text*]
            Italic --> Lists[Parse lists - item, 1. item]
            Lists --> Quotes[Parse blockquotes > text]
            Quotes --> Rules[Parse horizontal rules ---]
        end

        Rules --> Layout[Calculate layout with paper size]

        subgraph "PDF Generation"
            Layout --> Context[Create UIGraphicsPDFRenderer]
            Context --> BeginPage[Begin PDF page]
            BeginPage --> DrawHeader[Draw header<br/>timestamp, page number]
            DrawHeader --> DrawBody[Draw attributed text body]
            DrawBody --> CheckOverflow{Text overflows page?}

            CheckOverflow -->|Yes| BeginPage
            CheckOverflow -->|No| EndPage[End page]
        end

        EndPage --> PDFData[Return PDF Data]
    end

    PDFData --> Cache[Cache in viewModel.latestRenderedPageData]
    Cache --> Provisional

    subgraph "Provisional Page Composition"
        Provisional[Pass to ProvisionalPageManager]
        Provisional --> HashCheck{Cache valid?}

        HashCheck -->|Yes| UseCached[Use cached combined PDF]
        HashCheck -->|No| BuildNew

        subgraph "Build Combined PDF"
            BuildNew[Create new PDFDocument]
            BuildNew --> CopySaved[Copy saved pages]
            CopySaved --> AppendDraft[Append draft page s]
            AppendDraft --> Range[Track provisional range]
            Range --> DataRep[Get dataRepresentation ]
        end

        DataRep --> UpdateCache[Update cache with new data + hashes]
        UpdateCache --> UseCached
    end

    UseCached --> Display[DocumentViewModel.displayPDFData]
    Display --> PDFView[PDFView renders combined PDF]
    PDFView --> End([User sees live preview])

    style Start fill:#e1f5ff
    style End fill:#c8e6c9
```

## PDF Finalization Pipeline (Text Pages)

```mermaid
flowchart TB
    Start([User taps Done])
    Start --> Flush

    Flush[Flush draft to ensure latest saved]
    Flush --> Finalize

    subgraph "Finalization"
        Finalize[DocumentEditView.finalizeTextPageIfNeeded]
        Finalize --> GetCached[Get cached rendered PDF]
        GetCached --> AppendDoc[DocumentViewModel.appendTextPage]

        AppendDoc --> Combine

        subgraph "PDF Combination"
            Combine[Combine saved PDF + text page PDF]
            Combine --> CreateDoc[PDFDocument from saved data]
            CreateDoc --> CreateText[PDFDocument from text page data]
            CreateText --> Merge[Merge page-by-page]
        end

        Merge --> UpdateMeta[Update metadata<br/>pageCount, fullText, ocrCompleted: false]
        UpdateMeta --> SaveDoc[NoteDocument.save ]
    end

    SaveDoc --> ClearProv[Clear provisional data]
    ClearProv --> DeleteDraft[Delete draft from disk]
    DeleteDraft --> Refresh[Refresh display PDF]
    Refresh --> End([Text page finalized])

    style Start fill:#e1f5ff
    style End fill:#c8e6c9
```

## PDF Page Indexing (1-based Convention)

```mermaid
flowchart LR
    UI[UI Layer<br/>1-based pages]
    UI -->|"page 1"| Wrapper

    subgraph "Extension Wrappers"
        Wrapper[PDFDocument+PageIndexing]
        Wrapper -->|"index = page - 1"| Convert[Convert to 0-based]
    end

    Convert -->|"index 0"| PDFKit[PDFKit API<br/>0-based pages]
    PDFKit -->|"PDFPage"| Convert2[Convert to 1-based]
    Convert2 -->|"page 1"| UI

    style UI fill:#e1f5ff
    style PDFKit fill:#fff4e1
```

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| **PDF Viewing** |
| Load PDF from .yianazip | 10-50ms | Depends on file size |
| PDFKit page render | 16-50ms | Cached after first render |
| Page navigation | <16ms | PDFKit cache |
| **Scanning** |
| VisionKit capture | Instant | Automatic detection |
| Image to PDF conversion | 50-200ms | Per image, depends on resolution |
| Append to document | 20-100ms | Depends on existing page count |
| **Text Pages** |
| Markdown parse + render | 50-200ms | Depends on content length |
| Provisional composition (cache hit) | <1ms | Hash-based cache |
| Provisional composition (cache miss) | 20-50ms | Typical documents |
| Provisional composition (large docs) | 50-120ms | 50+ pages |
| Text page finalization | 20-100ms | Append + metadata update |

## Memory Characteristics

| Component | Memory Usage |
|-----------|--------------|
| PDF page cache (PDFKit) | ~500KB-2MB per page |
| Provisional page data | <1MB (single text page) |
| Combined PDF cache | 2x saved PDF size (temporary) |
| Scanned image buffer | ~5-10MB per image (temporary) |

## Implementation Files

- **PDF Viewing**: `Yiana/Views/PDFViewer.swift`, `Yiana/Extensions/PDFDocument+PageIndexing.swift`
- **Scanning**: `Yiana/Views/ScannerView.swift`, `Yiana/Services/ScanningService.swift`
- **Text Pages**: `Yiana/Services/TextPagePDFRenderer.swift`, `Yiana/ViewModels/TextPageEditorViewModel.swift`
- **Provisional Composition**: `Yiana/Services/ProvisionalPageManager.swift`
- **Document Integration**: `Yiana/ViewModels/DocumentViewModel.swift`, `Yiana/Models/NoteDocument.swift`
