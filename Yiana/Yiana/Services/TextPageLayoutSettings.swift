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

enum SidebarPosition: String, CaseIterable, Identifiable, Codable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}

enum SidebarThumbnailSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }

    var sidebarWidth: CGFloat {
        switch self {
        case .small:
            return 150
        case .medium:
            return 180
        case .large:
            return 210
        }
    }

    var thumbnailSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 110, height: 150)
        case .medium:
            return CGSize(width: 140, height: 190)
        case .large:
            return CGSize(width: 170, height: 230)
        }
    }
}

actor TextPageLayoutSettings {
    static let shared = TextPageLayoutSettings()

    private let defaults: UserDefaults
    private let paperSizeKey = "textPage.preferredPaperSize"
    private let sidebarPositionKey = "textPage.sidebarPosition"
    private let thumbnailSizeKey = "textPage.thumbnailSize"

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

    func preferredSidebarPosition() -> SidebarPosition {
        if let rawValue = defaults.string(forKey: sidebarPositionKey),
           let stored = SidebarPosition(rawValue: rawValue) {
            return stored
        }
        return .right
    }

    func setPreferredSidebarPosition(_ position: SidebarPosition) {
        defaults.set(position.rawValue, forKey: sidebarPositionKey)
    }

    func preferredThumbnailSize() -> SidebarThumbnailSize {
        if let rawValue = defaults.string(forKey: thumbnailSizeKey),
           let stored = SidebarThumbnailSize(rawValue: rawValue) {
            return stored
        }
        return .medium
    }

    func setPreferredThumbnailSize(_ size: SidebarThumbnailSize) {
        defaults.set(size.rawValue, forKey: thumbnailSizeKey)
    }
}
