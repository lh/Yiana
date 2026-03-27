# Yiana Project Overview

## Purpose
Yiana is a document scanning and PDF management app for iOS, iPadOS, and macOS. Built for clinical workflow: scan patient documents, extract addresses via OCR, compose and render referral letters, manage a work list of patients to review.

## Tech Stack
- **Language:** Swift (100% of active code)
- **UI:** SwiftUI with `#if os()` guards for platform differences
- **Platforms:** iOS 15+, macOS 12+
- **Documents:** UIDocument (iOS) / NSDocument (macOS), `.yianazip` packages via ZIPFoundation
- **PDF:** PDFKit (read-only, 1-based page indexing everywhere)
- **Cloud:** iCloud Drive (`iCloud.com.vitygas.Yiana`)
- **Database:** GRDB.swift for entity DB and NHS lookup
- **Rendering:** Typst via Rust FFI (YianaRenderer, 30ms for 3 PDFs)
- **OCR:** Vision framework on-device (OnDeviceOCRService)
- **Extraction:** NLTagger + NSDataDetector (YianaExtraction package)

## Current State (2026-03-27)
- Version 2.0, build 51 on TestFlight
- Fully self-contained — no server dependencies
- Devon (Mac mini) retired to iCloud sync node only
- 623 commits, 8.5 months of development
- 20 open GitHub Issues tracking remaining work

## Key Workflows
1. **Scan** — iOS camera via VisionKit, imports to .yianazip
2. **Extract** — On-device OCR, address extraction with NHS lookup
3. **Compose** — Body text editing, auto-filled recipients from address data
4. **Render** — Typst templates produce postal letters and envelopes as PDF
5. **Work list** — Track patients to review in current session
