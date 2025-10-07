//
//  TextPageMarkdownFormatter.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Minimal Markdown formatter tailored for the text-page workflow. Supports the
//  subset of Markdown exposed by the editor toolbar (headings, emphasis,
//  blockquotes, lists, horizontal rules, and inline code). Produces attributed
//  strings with consistent typography so both the PDF renderer and in-app
//  preview share the same styling.
//

import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if os(iOS)
private let boldTrait: UIFontDescriptor.SymbolicTraits = .traitBold
private let italicTrait: UIFontDescriptor.SymbolicTraits = .traitItalic
#else
private let boldTrait: NSFontDescriptor.SymbolicTraits = .bold
private let italicTrait: NSFontDescriptor.SymbolicTraits = .italic
#endif

struct TextPageMarkdownFormatter {
    struct Styles {
        let bodyFont: PlatformFont
        let headingFonts: [Int: PlatformFont]
        let boldFont: PlatformFont
        let italicFont: PlatformFont
        let monoFont: PlatformFont
        let bodyColor: PlatformColor
        let secondaryColor: PlatformColor
        let accentColor: PlatformColor
        let lineSpacing: CGFloat
        let paragraphSpacing: CGFloat
        let headingSpacing: CGFloat
        let listIndent: CGFloat
        let blockquoteIndent: CGFloat
    }

    struct Result {
        let attributed: NSAttributedString
        let plainText: String
    }

    static func makePDFBody(from markdown: String, styles: Styles) -> Result {
        MarkdownAttributedBuilder(styles: styles).build(from: markdown)
    }

    static func makePreviewAttributedString(from markdown: String) -> AttributedString {
        let typography = TextPageTypography.current()
        let styles = Styles(
            bodyFont: typography.bodyFont,
            headingFonts: typography.headingFonts,
            boldFont: typography.boldFont,
            italicFont: typography.italicFont,
            monoFont: typography.monoFont,
            bodyColor: typography.bodyColor,
            secondaryColor: typography.secondaryColor,
            accentColor: typography.accentColor,
            lineSpacing: 4,
            paragraphSpacing: typography.bodyFont.pointSize * 0.6,
            headingSpacing: typography.bodyFont.pointSize * 0.8,
            listIndent: 20,
            blockquoteIndent: 24
        )
        let result = MarkdownAttributedBuilder(styles: styles).build(from: markdown)
        return AttributedString(result.attributed)
    }
}

private final class MarkdownAttributedBuilder {
    private let styles: TextPageMarkdownFormatter.Styles

    init(styles: TextPageMarkdownFormatter.Styles) {
        self.styles = styles
    }

    func build(from markdown: String) -> TextPageMarkdownFormatter.Result {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TextPageMarkdownFormatter.Result(attributed: NSAttributedString(string: ""), plainText: "")
        }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        let output = NSMutableAttributedString()
        var plainLines: [String] = []
        var isFirstBlock = true

        for rawLine in lines {
            let line = String(rawLine)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                plainLines.append("")
                if !isFirstBlock {
                    output.append(NSAttributedString(string: "\n"))
                }
                isFirstBlock = false
                continue
            }

            let block = classifyBlock(from: trimmedLine)
            let blockResult = render(block: block)

            if !isFirstBlock {
                output.append(NSAttributedString(string: "\n"))
            }
            output.append(blockResult.attributed)
            plainLines.append(blockResult.plainText)
            isFirstBlock = false
        }

        let plainText = plainLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return TextPageMarkdownFormatter.Result(attributed: output, plainText: plainText)
    }

    private func classifyBlock(from line: String) -> Block {
        if let horizontal = horizontalRuleBlock(for: line) {
            return horizontal
        }
        if let heading = headingBlock(for: line) {
            return heading
        }
        if let unordered = unorderedListBlock(for: line) {
            return unordered
        }
        if let ordered = orderedListBlock(for: line) {
            return ordered
        }
        if let quote = blockquoteBlock(for: line) {
            return quote
        }
        return Block(kind: .paragraph, content: line, ordinal: nil)
    }

    private func render(block: Block) -> (attributed: NSAttributedString, plainText: String) {
        switch block.kind {
        case .horizontalRule:
            let rule = String(repeating: "\u{2500}", count: 24)
            let style = paragraphStyle(for: .horizontalRule)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: styles.monoFont,
                .foregroundColor: styles.secondaryColor,
                .paragraphStyle: style
            ]
            return (NSAttributedString(string: rule, attributes: attributes), "")
        case .heading:
            let font = font(for: block.kind)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraphStyle(for: block.kind)
            ]
            let (content, plain) = inlineAttributedString(for: block.content, baseAttributes: baseAttributes, baseFont: font)
            return (content, plain)
        case .blockquote:
            let font = font(for: block.kind)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.secondaryColor,
                .paragraphStyle: paragraphStyle(for: block.kind)
            ]
            let (content, plain) = inlineAttributedString(for: block.content, baseAttributes: baseAttributes, baseFont: font)
            return (content, plain)
        case .unorderedList:
            let font = styles.bodyFont
            let paragraph = paragraphStyle(for: block.kind)
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraph
            ]
            let bullet = NSAttributedString(string: "•\t", attributes: prefixAttributes)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraph
            ]
            let (content, plainContent) = inlineAttributedString(for: block.content, baseAttributes: baseAttributes, baseFont: font)
            let composed = NSMutableAttributedString()
            composed.append(bullet)
            composed.append(content)
            return (composed, "• " + plainContent)
        case .orderedList:
            let font = styles.bodyFont
            let paragraph = paragraphStyle(for: block.kind)
            let marker = "\(block.ordinal ?? 1). "
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraph
            ]
            let markerAttr = NSAttributedString(string: marker, attributes: prefixAttributes)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraph
            ]
            let (content, plainContent) = inlineAttributedString(for: block.content, baseAttributes: baseAttributes, baseFont: font)
            let composed = NSMutableAttributedString()
            composed.append(markerAttr)
            composed.append(content)
            return (composed, marker + plainContent)
        case .paragraph:
            let font = styles.bodyFont
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: styles.bodyColor,
                .paragraphStyle: paragraphStyle(for: block.kind)
            ]
            return inlineAttributedString(for: block.content, baseAttributes: baseAttributes, baseFont: font)
        }
    }

    private func inlineAttributedString(for text: String,
                                        baseAttributes: [NSAttributedString.Key: Any],
                                        baseFont: PlatformFont) -> (NSAttributedString, String) {
        let segments = parseSegments(in: text)
        return render(segments: segments, baseAttributes: baseAttributes, baseFont: baseFont)
    }

    private func render(segments: [InlineSegment],
                        baseAttributes: [NSAttributedString.Key: Any],
                        baseFont: PlatformFont) -> (NSAttributedString, String) {
        let output = NSMutableAttributedString()
        var plain = ""

        for segment in segments {
            switch segment {
            case .text(let value):
                plain += value
                output.append(NSAttributedString(string: value, attributes: baseAttributes))
            case .bold(let inner):
                var attributes = baseAttributes
                let derivedFont = boldFont(from: baseFont)
                attributes[.font] = derivedFont
                let (child, childPlain) = render(segments: inner, baseAttributes: attributes, baseFont: derivedFont)
                output.append(child)
                plain += childPlain
            case .italic(let inner):
                var attributes = baseAttributes
                let derivedFont = italicFont(from: baseFont)
                attributes[.font] = derivedFont
                let (child, childPlain) = render(segments: inner, baseAttributes: attributes, baseFont: derivedFont)
                output.append(child)
                plain += childPlain
            case .code(let value):
                plain += value
                var attributes = baseAttributes
                attributes[.font] = styles.monoFont
                attributes[.foregroundColor] = styles.secondaryColor
                output.append(NSAttributedString(string: value, attributes: attributes))
            }
        }

        return (output, plain)
    }

    private func parseSegments(in text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            if !buffer.isEmpty {
                segments.append(.text(buffer))
                buffer.removeAll(keepingCapacity: true)
            }
        }

        while index < text.endIndex {
            if text[index...].hasPrefix("**") || text[index...].hasPrefix("__") {
                let marker = text[index...].hasPrefix("**") ? "**" : "__"
                if let end = findClosingMarker(marker, in: text, from: index) {
                    flushBuffer()
                    let contentStart = text.index(index, offsetBy: marker.count)
                    let innerText = String(text[contentStart..<end])
                    segments.append(.bold(parseSegments(in: innerText)))
                    index = text.index(end, offsetBy: marker.count)
                    continue
                }
            }

            if text[index] == "*" || text[index] == "_" {
                let marker = String(text[index])
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == text[index] {
                    // handled by bold branch
                } else if let end = findClosingMarker(marker, in: text, from: index) {
                    flushBuffer()
                    let contentStart = text.index(after: index)
                    let innerText = String(text[contentStart..<end])
                    segments.append(.italic(parseSegments(in: innerText)))
                    index = text.index(after: end)
                    continue
                }
            }

            if text[index] == "`",
               let end = findClosingMarker("`", in: text, from: index) {
                flushBuffer()
                let contentStart = text.index(after: index)
                let code = String(text[contentStart..<end])
                segments.append(.code(code))
                index = text.index(after: end)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flushBuffer()
        return segments
    }

    private func findClosingMarker(_ marker: String, in text: String, from start: String.Index) -> String.Index? {
        var search = text.index(start, offsetBy: marker.count)
        while search < text.endIndex {
            if text[search...].hasPrefix(marker) {
                return search
            }
            search = text.index(after: search)
        }
        return nil
    }

    private func headingBlock(for line: String) -> Block? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 3 else { return nil }
        let level = hashes.count
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return Block(kind: .heading(level), content: String(text), ordinal: nil)
    }

    private func unorderedListBlock(for line: String) -> Block? {
        let markers = ["- ", "* ", "+ "]
        for marker in markers where line.hasPrefix(marker) {
            let content = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return Block(kind: .unorderedList, content: String(content), ordinal: nil)
        }
        return nil
    }

    private func orderedListBlock(for line: String) -> Block? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberPart = line[..<dotIndex]
        guard let ordinal = Int(numberPart) else { return nil }
        let remainder = line[line.index(after: dotIndex)...].trimmingCharacters(in: .whitespaces)
        return Block(kind: .orderedList, content: String(remainder), ordinal: ordinal)
    }

    private func blockquoteBlock(for line: String) -> Block? {
        guard line.hasPrefix(">") else { return nil }
        let content = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return Block(kind: .blockquote, content: String(content), ordinal: nil)
    }

    private func horizontalRuleBlock(for line: String) -> Block? {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        if stripped == "---" || stripped == "***" || stripped == "___" {
            return Block(kind: .horizontalRule, content: "", ordinal: nil)
        }
        return nil
    }

    private func paragraphStyle(for kind: Block.Kind) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = styles.lineSpacing
        style.paragraphSpacing = styles.paragraphSpacing
        style.alignment = .left

        switch kind {
        case .heading:
            style.paragraphSpacing = styles.headingSpacing
        case .unorderedList, .orderedList:
            style.headIndent = styles.listIndent
            style.firstLineHeadIndent = styles.listIndent
            style.tabStops = [NSTextTab(textAlignment: .left, location: styles.listIndent)]
        case .blockquote:
            style.headIndent = styles.blockquoteIndent
            style.firstLineHeadIndent = styles.blockquoteIndent
        case .horizontalRule:
            style.alignment = .center
        case .paragraph:
            break
        }

        return style
    }

    private func font(for kind: Block.Kind) -> PlatformFont {
        switch kind {
        case .heading(let level):
            if let font = styles.headingFonts[level] {
                if level == 3 {
                    return italicFont(from: font)
                }
                return boldFont(from: font)
            }
            return styles.headingFonts[3] ?? styles.bodyFont
        case .blockquote:
            return italicFont(from: styles.bodyFont)
        default:
            return styles.bodyFont
        }
    }

    private func boldFont(from base: PlatformFont) -> PlatformFont {
        let candidate = base.applyingTraits(boldTrait)
        if fontsEqual(candidate, base) {
            return styles.boldFont
        }
        return candidate
    }

    private func italicFont(from base: PlatformFont) -> PlatformFont {
        let candidate = base.applyingTraits(italicTrait)
        if fontsEqual(candidate, base) {
            return styles.italicFont
        }
        return candidate
    }

#if os(iOS)
    private func fontsEqual(_ lhs: UIFont, _ rhs: UIFont) -> Bool {
        lhs.fontDescriptor == rhs.fontDescriptor && lhs.pointSize == rhs.pointSize
    }
#else
    private func fontsEqual(_ lhs: NSFont, _ rhs: NSFont) -> Bool {
        lhs.fontDescriptor == rhs.fontDescriptor && abs(lhs.pointSize - rhs.pointSize) < .ulpOfOne
    }
#endif

    private struct Block {
        enum Kind {
            case heading(Int)
            case unorderedList
            case orderedList
            case blockquote
            case horizontalRule
            case paragraph
        }

        let kind: Kind
        let content: String
        let ordinal: Int?
    }

    private enum InlineSegment {
        case text(String)
        case bold([InlineSegment])
        case italic([InlineSegment])
        case code(String)
    }
}
