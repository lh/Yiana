# System Patterns

## Architecture Pattern
**Document-Based App Architecture**
- Each note is a UIDocument subclass
- Documents stored as `.yianazip` packages containing:
  - `document.pdf` - The scanned PDF
  - `metadata.json` - OCR text, tags, timestamps

## Design Patterns
1. **MVVM (Model-View-ViewModel)**
   - Models: NoteDocument (UIDocument subclass)
   - ViewModels: DocumentListViewModel, DocumentViewModel
   - Views: SwiftUI views

2. **Repository Pattern**
   - DocumentRepository handles all document CRUD operations
   - Abstracts iCloud Document storage

3. **Coordinator Pattern** (for navigation)
   - DocumentCoordinator manages document flow
   - ScanningCoordinator handles scanning flow

## File Organization
```
Yiana/
├── Models/
│   ├── NoteDocument.swift
│   └── DocumentMetadata.swift
├── ViewModels/
│   ├── DocumentListViewModel.swift
│   └── DocumentViewModel.swift
├── Views/
│   ├── DocumentListView.swift
│   ├── DocumentView.swift
│   └── ScannerView.swift
├── Services/
│   ├── DocumentRepository.swift
│   └── ScanningService.swift
└── Utilities/
    └── FileManager+Extensions.swift
```

## Key Principles
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Platform-specific code**: Use compiler directives for iOS-only features (VisionKit)
- **Testability**: All business logic in ViewModels and Services for easy testing