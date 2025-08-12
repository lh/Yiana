# Yiana Project Structure

## Root Directory
```
Yiana/
├── .gitignore
├── README.md           - Project documentation
├── PLAN.md            - Phased implementation roadmap
├── CLAUDE.md          - AI assistant context
├── memory-bank/       - Project memory storage
│   └── activeContext.md
├── docs/              - Extended documentation
│   ├── DataStructures.md
│   └── API.md
└── Yiana/            - Main project directory
```

## Xcode Project Structure
```
Yiana/
├── Yiana.xcodeproj/
│   └── project.pbxproj    - Xcode project configuration
├── Yiana/                 - Main app code
│   ├── YianaApp.swift     - App entry point (@main)
│   ├── ContentView.swift  - Root view
│   ├── Info.plist         - App configuration
│   ├── Yiana.entitlements - App capabilities (iCloud)
│   ├── Assets.xcassets/   - Images and colors
│   ├── Models/            - Data models
│   │   ├── DocumentMetadata.swift
│   │   └── NoteDocument.swift
│   ├── ViewModels/        - Business logic
│   │   ├── DocumentListViewModel.swift
│   │   └── DocumentViewModel.swift
│   ├── Views/             - UI components
│   │   ├── DocumentListView.swift
│   │   ├── DocumentEditView.swift
│   │   ├── DocumentReadView.swift
│   │   ├── PDFViewer.swift
│   │   ├── PageManagementView.swift
│   │   └── ScannerView.swift
│   ├── Services/          - Backend services
│   │   ├── DocumentRepository.swift
│   │   └── ScanningService.swift
│   ├── Utilities/         - Helper code
│   └── Tests/            - Internal tests
├── YianaTests/           - Unit tests
│   ├── YianaTests.swift
│   ├── DocumentMetadataTests.swift
│   ├── NoteDocumentTests.swift
│   ├── DocumentRepositoryTests.swift
│   ├── DocumentListViewModelTests.swift
│   ├── DocumentViewModelTests.swift
│   └── ScanningServiceTests.swift
└── YianaUITests/         - UI tests

## Key Files
- **YianaApp.swift**: Main app entry with @main, handles URL imports
- **DocumentMetadata.swift**: Core data structure for document info
- **NoteDocument.swift**: UIDocument subclass for document handling
- **.yianazip format**: Custom package (PDF + metadata.json)

## Development Phases (from PLAN.md)
1. ✅ Project Structure & Core Models
2. 🔄 Remove Core Data & Setup Document Repository
3. ⏳ ViewModels with TDD
4. ⏳ Basic UI Implementation
5. ⏳ Scanner Integration (iOS only)
6. ⏳ PDF Viewer Integration
7. ⏳ iCloud Configuration
8. ⏳ Polish & Error Handling