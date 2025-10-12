//
//  PageClipboardPayload.swift
//  Yiana
//

import Foundation

/// Represents the payload for page copy/cut operations that can be persisted across app sessions
struct PageClipboardPayload: Codable {
    /// Operation type for the clipboard payload
    enum Operation: String, Codable {
        case copy
        case cut
    }

    /// Version for forward compatibility
    let version: Int

    /// Unique identifier for this clipboard payload
    let id: UUID

    /// Source document ID (nil for external sources)
    let sourceDocumentID: UUID?

    /// The operation type (copy or cut)
    let operation: Operation

    /// Number of pages in the payload
    let pageCount: Int

    /// The actual PDF data containing the pages
    let pdfData: Data

    /// When this payload was created
    let createdAt: Date

    /// Optional: For cut operations, the original document data before cut
    let sourceDataBeforeCut: Data?

    /// Optional: The zero-based indices that were cut (for restoration)
    let cutIndices: [Int]?

    init(version: Int = 1,
         id: UUID = UUID(),
         sourceDocumentID: UUID?,
         operation: Operation,
         pageCount: Int,
         pdfData: Data,
         createdAt: Date = Date(),
         sourceDataBeforeCut: Data? = nil,
         cutIndices: [Int]? = nil) {
        self.version = version
        self.id = id
        self.sourceDocumentID = sourceDocumentID
        self.operation = operation
        self.pageCount = pageCount
        self.pdfData = pdfData
        self.createdAt = createdAt
        self.sourceDataBeforeCut = sourceDataBeforeCut
        self.cutIndices = cutIndices
    }
}

/// Errors that can occur during page operations
enum PageOperationError: LocalizedError, Equatable {
    case documentInConflict
    case documentClosed
    case selectionTooLarge(limit: Int)
    case sourceDocumentUnavailable
    case unableToSerialise
    case provisionalPagesNotSupported
    case clipboardDataCorrupted
    case versionMismatch(expected: Int, actual: Int)
    case noValidPagesSelected
    case insertionFailed

    var errorDescription: String? {
        switch self {
        case .documentInConflict:
            return "Document has sync conflicts. Please resolve them first."
        case .documentClosed:
            return "Document is closed. Please open it first."
        case .selectionTooLarge(let limit):
            return "Selection too large. Maximum \(limit) pages allowed."
        case .sourceDocumentUnavailable:
            return "Source document is unavailable."
        case .unableToSerialise:
            return "Unable to process PDF data."
        case .provisionalPagesNotSupported:
            return "Save draft text pages before copying."
        case .clipboardDataCorrupted:
            return "Clipboard data is corrupted."
        case .versionMismatch(let expected, let actual):
            return "Clipboard format version mismatch (expected \(expected), got \(actual))."
        case .noValidPagesSelected:
            return "No valid pages selected for operation."
        case .insertionFailed:
            return "Failed to insert pages into document."
        }
    }
}

/// Limits for page operations to prevent memory issues
struct PageOperationLimits {
    static let warningThreshold = 50
    static let hardLimit = 200
    static let chunkSize = 25
}