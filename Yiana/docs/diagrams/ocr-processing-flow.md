# OCR Processing Flow

This document describes the OCR processing pipeline, including the backend service architecture and integration with the main app.

## OCR Service Architecture

```mermaid
graph TB
    subgraph "Mac mini (Backend)"
        CLI[YianaOCRService CLI]
        DW[DirectoryWatcher]
        Queue[Processing Queue]
        Worker[OCR Worker Thread]
        VF[Vision Framework]
        Writer[Results Writer]

        CLI --> DW
        DW --> Queue
        Queue --> Worker
        Worker --> VF
        VF --> Worker
        Worker --> Writer
    end

    subgraph "iCloud Drive"
        Docs[(Documents/)]
        OCRDir[.ocr_results/]
    end

    subgraph "iOS/iPadOS/macOS App"
        OCRP[OCRProcessor]
        DVM[DocumentViewModel]
        Search[Search Feature]
    end

    DW -.Watch.-> Docs
    Writer --> OCRDir
    Writer -.Update metadata.-> Docs
    OCRP -.Read.-> OCRDir
    DVM --> OCRP
    Search --> OCRP

    style CLI fill:#ffe1f5
    style Docs fill:#e8f5e9
```

## OCR Processing State Machine

```mermaid
stateDiagram-v2
    [*] --> Watching: Service starts

    Watching --> Detected: File change event
    Detected --> CheckMetadata: Read .yianazip

    CheckMetadata --> Skipped: ocrCompleted == true
    CheckMetadata --> Queued: ocrCompleted == false

    Queued --> Processing: Worker available
    Processing --> Extracting: Load PDF
    Extracting --> Recognizing: For each page

    Recognizing --> Building: Vision text observations
    Building --> Writing: Build JSON
    Writing --> Updating: Write .ocr_results/

    Updating --> Complete: Update metadata ocrCompleted=true
    Complete --> Watching

    Skipped --> Watching

    Processing --> Failed: Error occurs
    Failed --> Watching: Log error

    style Complete fill:#c8e6c9
    style Failed fill:#ffcdd2
```

## Detailed OCR Processing Flow

```mermaid
sequenceDiagram
    participant IC as iCloud Drive
    participant DW as DirectoryWatcher
    participant Q as Processing Queue
    participant W as OCR Worker
    participant VF as Vision Framework
    participant RW as Results Writer
    participant App as iOS/macOS App

    loop Monitor every 5s
        DW->>IC: List .yianazip files
        IC-->>DW: File list

        loop For each file
            DW->>IC: Read metadata
            IC-->>DW: DocumentMetadata

            alt ocrCompleted == false AND not in queue
                DW->>Q: enqueue(documentURL)
            end
        end
    end

    Q->>W: Dequeue next document
    W->>IC: Read .yianazip
    IC-->>W: File data

    W->>W: Extract PDF from package

    W->>W: PDFDocument(data: pdfData)

    loop For each page (0-based PDFKit)
        W->>W: Get PDFPage at index
        W->>W: Render page to CGImage

        W->>VF: VNRecognizeTextRequest
        VF->>VF: Perform text recognition
        VF-->>W: [VNRecognizedTextObservation]

        W->>W: Extract text + bounds
        W->>W: Build page JSON<br/>(pageNumber: index+1, text, textBlocks)
    end

    W->>W: Build complete OCR JSON
    W->>RW: write(docID, ocrResults)

    RW->>IC: Write .ocr_results/[docID].json
    RW->>IC: Update .yianazip metadata<br/>(ocrCompleted: true, fullText: concatenated)

    IC-->>App: iCloud sync
    App->>App: UI updates (search available)
```

## Vision Framework Text Recognition Detail

```mermaid
flowchart TB
    Start([PDF page])
    Start --> Render

    subgraph "Page Rendering"
        Render[Render PDFPage to CGImage]
        Render --> Image[CGImage 300 DPI]
    end

    Image --> Request

    subgraph "Vision Framework Processing"
        Request[Create VNRecognizeTextRequest]
        Request --> Config[Configure<br/>recognitionLevel: accurate<br/>languages: en-US]
        Config --> Handler[Create VNImageRequestHandler]
        Handler --> Perform[Perform request]

        Perform --> Detect[Detect text regions]
        Detect --> Segment[Segment characters]
        Segment --> Recognize[Recognize characters]
        Recognize --> Confidence[Calculate confidence scores]
    end

    Confidence --> Observations

    subgraph "Results Processing"
        Observations[VNRecognizedTextObservation array]
        Observations --> Loop{For each observation}

        Loop --> TopCandidate[Get top candidate<br/>minimumConfidence: 0.5]
        TopCandidate --> Extract[Extract text + bounding box]
        Extract --> Transform[Transform coordinates<br/>Vision → PDF space]
        Transform --> TextBlock[Create TextBlock JSON]

        TextBlock --> Loop
        Loop --> Aggregate[Aggregate all blocks]
    end

    Aggregate --> PageText[Page full text<br/>concatenated blocks]
    PageText --> End([OCR result for page])

    style Start fill:#e1f5ff
    style End fill:#c8e6c9
```

## OCR Results JSON Structure

```json
{
  "documentId": "UUID",
  "processedDate": "2025-10-08T12:34:56Z",
  "pages": [
    {
      "pageNumber": 1,
      "text": "Full page text concatenated from all blocks...",
      "textBlocks": [
        {
          "text": "Individual text block",
          "bounds": {
            "x": 72.0,
            "y": 100.0,
            "width": 450.0,
            "height": 24.0
          },
          "confidence": 0.95
        }
      ]
    }
  ]
}
```

## App-Side OCR Integration

```mermaid
flowchart TB
    Start([User searches])
    Start --> Check

    Check{OCR completed?}
    Check -->|No| NoResults[Return title-only results]
    Check -->|Yes| Load

    Load[OCRProcessor.getOCRResultsPath]
    Load --> Read

    Read[Read .ocr_results/[docID].json]
    Read --> Parse

    subgraph "JSON Parsing"
        Parse[Decode OCR JSON]
        Parse --> Pages[Extract pages array]
        Pages --> Search[Search each page.text]
    end

    Search --> Matches{Found matches?}
    Matches -->|Yes| BuildResults

    subgraph "Result Building"
        BuildResults[For each match]
        BuildResults --> Snippet[Extract text snippet around match]
        Snippet --> PageNum[Get pageNumber 1-based]
        PageNum --> Result[Create SearchResult]
    end

    Result --> Display[Return results to UI]
    Matches -->|No| NoResults

    NoResults --> Display
    Display --> End([Show results])

    style Start fill:#e1f5ff
    style End fill:#c8e6c9
```

## OCR Service CLI Commands

```bash
# Start OCR service (watches iCloud Drive)
yiana-ocr watch

# Process single document
yiana-ocr process /path/to/document.yianazip

# Reprocess all documents (ignores ocrCompleted flag)
yiana-ocr reprocess --all

# Process documents in directory
yiana-ocr batch /path/to/documents/

# Check service status
yiana-ocr status

# Configuration
yiana-ocr config --recognition-level accurate
yiana-ocr config --languages en-US,en-GB
yiana-ocr config --watch-interval 5
```

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| **Directory Watching** |
| File system scan | 100-500ms | Every 5s default |
| Metadata read | 10-50ms | Per document |
| Queue check | <1ms | In-memory |
| **OCR Processing** |
| Page render to image | 50-200ms | 300 DPI |
| Vision text recognition | 200ms-2s | Per page, depends on complexity |
| JSON serialization | 10-50ms | Per document |
| Results write | 20-100ms | JSON file + metadata update |
| **Typical Documents** |
| 1-page document | 1-3s | Total processing time |
| 10-page document | 5-20s | Total processing time |
| 50-page document | 30-90s | Total processing time |

## Error Handling

```mermaid
flowchart TB
    Start([OCR error occurs])
    Start --> Type{Error type?}

    Type -->|File read error| Log1[Log: Unable to read document]
    Type -->|PDF parse error| Log2[Log: Invalid PDF format]
    Type -->|Vision error| Log3[Log: Text recognition failed]
    Type -->|Write error| Log4[Log: Unable to write results]

    Log1 --> Skip
    Log2 --> Skip
    Log3 --> Partial
    Log4 --> Retry

    Skip[Skip document, continue watching]
    Partial[Save partial results<br/>Mark pages without errors as complete]
    Retry[Retry write 3x with exponential backoff]

    Retry --> Success{Write succeeded?}
    Success -->|Yes| Complete[Mark ocrCompleted: true]
    Success -->|No| Log5[Log: Persistent write failure]

    Log5 --> Skip
    Partial --> Skip
    Complete --> End([Continue processing])
    Skip --> End

    style End fill:#c8e6c9
```

## iCloud Sync Coordination

The OCR service must coordinate with iCloud sync to avoid conflicts:

1. **Read coordination**: Wait for download to complete before processing
2. **Write coordination**: Use NSFileCoordinator for atomic updates
3. **Conflict resolution**: Last-write-wins (service updates take precedence)
4. **Sync triggers**: Atomic writes to .yianazip ensure iCloud detects changes

## Implementation Files

- **OCR Service**: `YianaOCRService/Sources/YianaOCR/`
  - `main.swift` - CLI entry point
  - `DirectoryWatcher.swift` - File system monitoring
  - `OCRProcessor.swift` - Vision framework integration
  - `ResultsWriter.swift` - JSON serialization + metadata updates

- **App Integration**: `Yiana/Services/OCRProcessor.swift`
  - Reads .ocr_results/ JSON files
  - Provides search interface
  - Exposes OCR status to UI

## Future Enhancements

- **Incremental OCR**: Process only new pages when appending to existing document
- **Priority queue**: User-initiated OCR gets higher priority than background batch
- **Multi-language**: Support for non-English documents
- **Format options**: Export to hOCR, ALTO XML for compatibility
- **Quality metrics**: Track confidence scores, provide UI indicators for low-confidence text
