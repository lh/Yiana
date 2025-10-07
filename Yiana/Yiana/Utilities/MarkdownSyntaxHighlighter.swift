//
//  MarkdownSyntaxHighlighter.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Applies lightweight syntax highlighting to Markdown used by the text page
//  editor. Only covers the subset of Markdown supported by the editor toolbar,
//  keeping the implementation predictable and cheap enough to run on every
//  keystroke.
//

import Foundation

#if os(iOS)
import UIKit
typealias MarkdownFont = UIFont
typealias MarkdownColor = UIColor
#elseif os(macOS)
import AppKit
typealias MarkdownFont = NSFont
typealias MarkdownColor = NSColor
#endif

struct MarkdownSyntaxHighlighter {
    struct Theme {
        var bodyFont: MarkdownFont
        var headingFonts: [Int: MarkdownFont]
        var boldFont: MarkdownFont
        var italicFont: MarkdownFont
        var monoFont: MarkdownFont
        var textColor: MarkdownColor
        var secondaryTextColor: MarkdownColor
        var accentColor: MarkdownColor

        static func defaultTheme() -> Theme {
            let typography = TextPageTypography.current()
            let headingFonts = typography.headingFonts
            return Theme(
                bodyFont: typography.bodyFont,
                headingFonts: headingFonts,
                boldFont: typography.boldFont,
                italicFont: typography.italicFont,
                monoFont: typography.monoFont,
                textColor: typography.bodyColor,
                secondaryTextColor: typography.secondaryColor,
                accentColor: typography.accentColor
            )
        }
    }

    private let theme: Theme

    init(theme: Theme = .defaultTheme()) {
        self.theme = theme
    }

    func applyHighlighting(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return }

        attributedString.setAttributes(baseAttributes(), range: fullRange)

        applyHeadingStyle(in: attributedString)
        applyItalicStyle(in: attributedString)
        applyBoldStyle(in: attributedString)
        applyBlockquoteStyle(in: attributedString)
        applyListStyle(in: attributedString)
        applyHorizontalRuleStyle(in: attributedString)
    }

    private func baseAttributes() -> [NSAttributedString.Key: Any] {
        [.font: theme.bodyFont, .foregroundColor: theme.textColor]
    }

    func baseTextAttributes() -> [NSAttributedString.Key: Any] {
        baseAttributes()
    }

    private func applyHeadingStyle(in attributedString: NSMutableAttributedString) {
        let pattern = "^(#{1,3})\\s+(.+)$"
        applyRegex(pattern, options: [.anchorsMatchLines], in: attributedString) { match, mutable in
            let markerRange = match.range(at: 1)
            let level: Int
            if let swiftRange = Range(markerRange, in: mutable.string) {
                level = mutable.string[swiftRange].count
            } else {
                level = 1
            }

            let baseFont = theme.headingFonts[level] ?? theme.bodyFont
            let headingFont: MarkdownFont
            switch level {
            case 1, 2:
                headingFont = applyTraits(boldTrait, to: baseFont)
            case 3:
                headingFont = applyTraits(italicTrait, to: baseFont)
            default:
                headingFont = baseFont
            }

            mutable.addAttribute(.font, value: headingFont, range: match.range(at: 0))
            mutable.addAttribute(.foregroundColor, value: theme.textColor, range: match.range(at: 0))
        }
    }

    private func applyBoldStyle(in attributedString: NSMutableAttributedString) {
        let pattern = "(\\*\\*|__)(.+?)(?:\\1)"
        applyRegex(pattern, options: [], in: attributedString) { match, mutable in
            let innerRange = match.range(at: 2)
            mutable.addAttribute(.font, value: theme.boldFont, range: innerRange)
        }
    }

    private func applyItalicStyle(in attributedString: NSMutableAttributedString) {
        let pattern = "(?<![\\*_])(\\*|_)(?!\\1)(?!\\s)(.+?)(?<!\\s)\\1(?!\\1)"
        applyRegex(pattern, options: [], in: attributedString) { match, mutable in
            let innerRange = match.range(at: 2)
            mutable.addAttribute(.font, value: theme.italicFont, range: innerRange)
        }
    }

    private func applyBlockquoteStyle(in attributedString: NSMutableAttributedString) {
        let pattern = "^>\\s+(.+)$"
        applyRegex(pattern, options: [.anchorsMatchLines], in: attributedString) { match, mutable in
            mutable.addAttribute(.foregroundColor, value: theme.secondaryTextColor, range: match.range(at: 0))
        }
    }

    private func applyListStyle(in attributedString: NSMutableAttributedString) {
        let unorderedPattern = "^\\s*[-\\*+]\\s+(.+)$"
        applyRegex(unorderedPattern, options: [.anchorsMatchLines], in: attributedString) { match, mutable in
            mutable.addAttribute(.foregroundColor, value: theme.textColor, range: match.range(at: 0))
        }

        let orderedPattern = "^\\s*\\d+\\.\\s+(.+)$"
        applyRegex(orderedPattern, options: [.anchorsMatchLines], in: attributedString) { match, mutable in
            mutable.addAttribute(.foregroundColor, value: theme.textColor, range: match.range(at: 0))
        }
    }

private func applyHorizontalRuleStyle(in attributedString: NSMutableAttributedString) {
        let pattern = "^\\s*---\\s*$"
        applyRegex(pattern, options: [.anchorsMatchLines], in: attributedString) { match, mutable in
            mutable.addAttribute(.foregroundColor, value: theme.secondaryTextColor, range: match.range(at: 0))
            mutable.addAttribute(.font, value: theme.monoFont, range: match.range(at: 0))
        }
    }

#if os(iOS)
    private typealias FontTraits = UIFontDescriptor.SymbolicTraits
    private let boldTrait: FontTraits = .traitBold
    private let italicTrait: FontTraits = .traitItalic
#else
    private typealias FontTraits = NSFontDescriptor.SymbolicTraits
    private let boldTrait: FontTraits = .bold
    private let italicTrait: FontTraits = .italic
#endif

    private func applyTraits(_ traits: FontTraits, to font: MarkdownFont) -> MarkdownFont {
#if os(iOS)
        let combined = font.fontDescriptor.symbolicTraits.union(traits)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(combined) {
            return MarkdownFont(descriptor: descriptor, size: font.pointSize)
        }
        return font
#else
        var combined = font.fontDescriptor.symbolicTraits
        combined.formUnion(traits)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(combined),
           let newFont = MarkdownFont(descriptor: descriptor, size: font.pointSize) {
            return newFont
        }
        return font
#endif
    }

    private func applyRegex(
        _ pattern: String,
        options: NSRegularExpression.Options,
        in attributedString: NSMutableAttributedString,
        handler: (NSTextCheckingResult, NSMutableAttributedString) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(location: 0, length: attributedString.length)
        regex.enumerateMatches(in: attributedString.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            handler(match, attributedString)
        }
    }
}
