//
//  ExtractionInput.swift
//  YianaExtraction
//
//  OCR text input for extraction.
//

import Foundation

/// OCR text for a single page, as produced by YianaOCRService or OnDeviceOCRService.
public struct ExtractionInput: Sendable {
    public let documentId: String
    public let pageNumber: Int       // 1-based
    public let text: String          // Full page OCR text
    public let confidence: Double    // OCR confidence 0...1

    public init(documentId: String, pageNumber: Int, text: String, confidence: Double = 0.85) {
        self.documentId = documentId
        self.pageNumber = pageNumber
        self.text = text
        self.confidence = confidence
    }
}
