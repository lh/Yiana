//
//  Extractor.swift
//  YianaExtraction
//
//  Protocol for address extraction strategies.
//

import Foundation

/// An extractor attempts to extract address data from OCR text.
/// Returns nil if the input doesn't match its expected format.
public protocol Extractor: Sendable {
    func extract(from input: ExtractionInput) -> AddressPageEntry?
}
