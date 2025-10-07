import XCTest
#if os(iOS)
import UIKit
#else
import AppKit
#endif
@testable import Yiana

final class TextPageMarkdownFormatterTests: XCTestCase {

    func testPlainTextStripsMarkdownMarkers() {
        let styles = makeStyles()
        let result = TextPageMarkdownFormatter.makePDFBody(
            from: "Heading\n\n**Bold** text with *italic* and `code`.",
            styles: styles
        )

        XCTAssertEqual(result.plainText, "Heading\n\nBold text with italic and code.")
    }

    func testAttributedTextAppliesExpectedFonts() {
        let styles = makeStyles()
        let result = TextPageMarkdownFormatter.makePDFBody(
            from: "Mix **bold** and *italic* plus `code`.",
            styles: styles
        )

        let attributed = result.attributed
        let nsString = attributed.string as NSString

        let boldRange = nsString.range(of: "bold")
        XCTAssertNotEqual(boldRange.location, NSNotFound)
        if let font = attributed.attribute(.font, at: boldRange.location, effectiveRange: nil) as? PlatformFont {
            XCTAssertTrue(fontHasTrait(font, trait: boldTrait()), "Bold segment should use a bold font")
        } else {
            XCTFail("Missing font attribute for bold text")
        }

        let italicRange = nsString.range(of: "italic")
        XCTAssertNotEqual(italicRange.location, NSNotFound)
        if let font = attributed.attribute(.font, at: italicRange.location, effectiveRange: nil) as? PlatformFont {
            XCTAssertTrue(fontHasTrait(font, trait: italicTrait()), "Italic segment should use an italic font")
        } else {
            XCTFail("Missing font attribute for italic text")
        }

        let codeRange = nsString.range(of: "code")
        XCTAssertNotEqual(codeRange.location, NSNotFound)
        if let font = attributed.attribute(.font, at: codeRange.location, effectiveRange: nil) as? PlatformFont {
            XCTAssertTrue(fontMatchesMono(font, mono: styles.monoFont), "Inline code should use the mono font")
        } else {
            XCTFail("Missing font attribute for code text")
        }
    }

    func testListPlainTextUsesBulletPrefix() {
        let styles = makeStyles()
        let result = TextPageMarkdownFormatter.makePDFBody(
            from: "- First item\n- Second item",
            styles: styles
        )

        XCTAssertEqual(result.plainText, "• First item\n• Second item")
    }

    func testHorizontalRuleProducesLineCharacters() {
        let styles = makeStyles()
        let result = TextPageMarkdownFormatter.makePDFBody(
            from: "Before\n\n---\n\nAfter",
            styles: styles
        )

        let lines = result.attributed.string.components(separatedBy: "\n")
        XCTAssertTrue(lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\u{2500}") }), "Horizontal rule should render as box drawing characters")
    }

    // MARK: - Helpers

    private func makeStyles() -> TextPageMarkdownFormatter.Styles {
        let typography = TextPageTypography.current()
        return TextPageMarkdownFormatter.Styles(
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
    }

    private func fontHasTrait(_ font: PlatformFont, trait: FontTrait) -> Bool {
        #if os(iOS)
        return font.fontDescriptor.symbolicTraits.contains(trait)
        #else
        return font.fontDescriptor.symbolicTraits.contains(trait)
        #endif
    }

    private func fontMatchesMono(_ font: PlatformFont, mono: PlatformFont) -> Bool {
        #if os(iOS)
        return font.fontDescriptor == mono.fontDescriptor && font.pointSize == mono.pointSize
        #else
        return font.fontDescriptor == mono.fontDescriptor && abs(font.pointSize - mono.pointSize) < .ulpOfOne
        #endif
    }

    private func boldTrait() -> FontTrait {
        #if os(iOS)
        return .traitBold
        #else
        return .bold
        #endif
    }

    private func italicTrait() -> FontTrait {
        #if os(iOS)
        return .traitItalic
        #else
        return .italic
        #endif
    }
}

#if os(iOS)
private typealias FontTrait = UIFontDescriptor.SymbolicTraits
#else
private typealias FontTrait = NSFontDescriptor.SymbolicTraits
#endif
