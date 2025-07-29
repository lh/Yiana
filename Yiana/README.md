# Yiana

**Y**iana **i**s **a**nother **n**otes **a**pp - A document scanning and PDF management app for iOS, iPadOS, and macOS.

## Overview

Yiana is a multiplatform document management app that focuses on:
- Scanning documents using iOS camera
- Managing PDFs with metadata and tags
- OCR processing via Mac mini server
- iCloud sync across devices

## Project Status

🚧 **Early Development** - Phase 1 (Core Models) completed

### Completed ✅
- DocumentMetadata data structure with tests
- NoteDocument (UIDocument) implementation for iOS
- Basic .yianazip file format support
- Project structure and GitHub setup

### In Progress 🔄
- Phase 2: Remove Core Data, implement Document Repository

### Planned 📋
- Document scanning UI (VisionKit)
- PDF viewing interface
- iCloud document sync
- macOS companion app
- OCR server integration

## Architecture

### Data Format
- **File Format**: `.yianazip` - A package containing PDF + metadata.json
- **Metadata**: Stores title, tags, dates, OCR status, extracted text
- **Storage**: iCloud Documents (via UIDocument/NSDocument)

### Platform Strategy
- iOS/iPadOS and macOS apps share data format but not implementation
- Each platform uses native document classes (UIDocument vs NSDocument)
- No complex abstractions or shared code protocols

### Key Technologies
- SwiftUI for UI
- UIDocument/NSDocument for document management
- PDFKit for PDF viewing (read-only)
- VisionKit for document scanning
- CloudKit for sync

## Documentation

- [Data Structures](docs/DataStructures.md) - Detailed format specifications
- [API Documentation](docs/API.md) - Class and method references
- [Development Plan](PLAN.md) - Phased implementation roadmap

## Building

Requirements:
- Xcode 15+
- iOS 17+ / macOS 14+
- Swift 5.9+

```bash
# Clone repository
git clone https://github.com/lh/Yiana.git
cd Yiana

# Open in Xcode
open Yiana.xcodeproj

# Build and run
# Select target device/simulator and press Cmd+R
```

## Testing

```bash
# Run all tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentMetadataTests
```

## Design Principles

1. **LEGO approach** - Use proven Apple frameworks, don't reinvent
2. **Simplicity** - Features that work well over feature bloat  
3. **Read-only PDFs** - No annotations to avoid memory issues
4. **Server-side OCR** - Heavy processing on Mac mini, not device

## License

[License details to be added]

## Contributing

This is currently a personal project. Contribution guidelines will be added when the project is more mature.