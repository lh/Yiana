//
//  RegistrationFormExtractor.swift
//  YianaExtraction
//
//  Extracts data from structured registration forms (e.g. hospital intake forms).
//  Highest priority extractor — fires first in the cascade.
//
//  TODO: Session 2 implementation
//

import Foundation

public struct RegistrationFormExtractor: Extractor {

    /// Text markers that identify this form type
    let triggers: [String] = ["Spire Healthcare", "Clearwater Medical"]

    public init() {}

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        // TODO: Session 2 — port from Python SpireFormExtractor
        return nil
    }
}
