# Yiana Project Overview

## Project Purpose
Yiana (Yiana is another notes app) is a document scanning and PDF management application for iOS, iPadOS, and macOS. The app focuses on:
- Scanning documents using iOS camera (VisionKit)
- Managing PDFs with metadata and tags
- OCR processing via Mac mini server
- iCloud sync across devices
- Read-only PDF viewing (no annotations to avoid memory issues)

## Tech Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum OS**: iOS 17+, macOS 14+
- **IDE**: Xcode 15+
- **Document Management**: UIDocument (iOS) / NSDocument (macOS)
- **PDF Handling**: PDFKit (read-only)
- **Document Scanning**: VisionKit
- **Cloud Storage**: iCloud Documents via CloudKit
- **File Format**: Custom `.yianazip` package (PDF + metadata.json)

## Architecture
- Platform-specific implementations (iOS/macOS share data format but not code)
- No complex abstractions or shared code protocols
- LEGO approach: Use proven Apple frameworks without reinventing
- Server-side OCR processing on Mac mini (not on device)

## Current Status
- Phase 1 completed: Core models and data structures
- Phase 2 in progress: Removing Core Data, implementing Document Repository
- Test-Driven Development approach with failing tests written first