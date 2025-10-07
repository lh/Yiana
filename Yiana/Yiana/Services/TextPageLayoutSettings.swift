//
//  TextPageLayoutSettings.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Stores user preferences for rendered text page layout, such as the
//  default paper size when generating PDF pages from Markdown. A4 is the
//  default, with the option to switch to US Letter for the North American
//  market.
//

import Foundation
import CoreGraphics

enum TextPagePaperSize: String, CaseIterable, Identifiable, Codable {
    case a4
    case usLetter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a4:
            return "A4"
        case .usLetter:
            return "US Letter"
        }
    }

    /// Size in points at 72 DPI.
    var size: CGSize {
        switch self {
        case .a4:
            return CGSize(width: 595.2, height: 841.8) // 210mm × 297mm
        case .usLetter:
            return CGSize(width: 612.0, height: 792.0) // 8.5" × 11"
        }
    }
}

actor TextPageLayoutSettings {
    static let shared = TextPageLayoutSettings()

    private let defaults: UserDefaults
    private let paperSizeKey = "textPage.preferredPaperSize"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func preferredPaperSize() -> TextPagePaperSize {
        if let rawValue = defaults.string(forKey: paperSizeKey),
           let stored = TextPagePaperSize(rawValue: rawValue) {
            return stored
        }
        return .a4
    }

    func setPreferredPaperSize(_ paperSize: TextPagePaperSize) {
        defaults.set(paperSize.rawValue, forKey: paperSizeKey)
    }
}
