#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct TextPageTypography {
    let bodyFont: PlatformFont
    let headingFonts: [Int: PlatformFont]
    let boldFont: PlatformFont
    let italicFont: PlatformFont
    let monoFont: PlatformFont
    let bodyColor: PlatformColor
    let secondaryColor: PlatformColor
    let accentColor: PlatformColor

    static func current() -> TextPageTypography {
        #if os(iOS)
        let body = UIFont.preferredFont(forTextStyle: .body)
        let headingFonts: [Int: UIFont] = [
            1: UIFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.6),
            2: UIFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.35),
            3: UIFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.1)
        ]
        let bold = UIFont(
            descriptor: body.fontDescriptor.withSymbolicTraits(.traitBold) ?? body.fontDescriptor,
            size: body.pointSize
        )
        let italic = UIFont(
            descriptor: body.fontDescriptor.withSymbolicTraits(.traitItalic) ?? body.fontDescriptor,
            size: body.pointSize
        )
        let mono = UIFont.monospacedSystemFont(ofSize: body.pointSize, weight: .regular)
        let bodyColor = UIColor.label
        let secondary = UIColor.secondaryLabel
        let accent = TextPageBrand.accentColor
        return TextPageTypography(
            bodyFont: body,
            headingFonts: headingFonts,
            boldFont: bold,
            italicFont: italic,
            monoFont: mono,
            bodyColor: bodyColor,
            secondaryColor: secondary,
            accentColor: accent
        )
        #else
        let body = NSFont.preferredFont(forTextStyle: .body)
        let headingFonts: [Int: NSFont] = [
            1: NSFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.6) ?? body,
            2: NSFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.35) ?? body,
            3: NSFont(descriptor: body.fontDescriptor, size: body.pointSize * 1.1) ?? body
        ]
        let boldDescriptor = body.fontDescriptor.withSymbolicTraits(.bold)
        let italicDescriptor = body.fontDescriptor.withSymbolicTraits(.italic)
        let bold = NSFont(descriptor: boldDescriptor, size: body.pointSize) ?? body
        let italic = NSFont(descriptor: italicDescriptor, size: body.pointSize) ?? body
        let mono = NSFont.monospacedSystemFont(ofSize: body.pointSize, weight: .regular)
        let bodyColor = NSColor.textColor
        let secondary = NSColor.secondaryLabelColor
        let accent = TextPageBrand.accentColor
        return TextPageTypography(
            bodyFont: body,
            headingFonts: headingFonts,
            boldFont: bold,
            italicFont: italic,
            monoFont: mono,
            bodyColor: bodyColor,
            secondaryColor: secondary,
            accentColor: accent
        )
        #endif
    }
}

#if os(iOS)
typealias FontDescriptorTraits = UIFontDescriptor.SymbolicTraits
#else
typealias FontDescriptorTraits = NSFontDescriptor.SymbolicTraits
#endif

extension PlatformFont {
    func applyingTraits(_ traits: FontDescriptorTraits) -> PlatformFont {
        #if os(iOS)
        let combined = fontDescriptor.symbolicTraits.union(traits)
        if let descriptor = fontDescriptor.withSymbolicTraits(combined) {
            return PlatformFont(descriptor: descriptor, size: pointSize)
        }
        return self
        #else
        var combined = fontDescriptor.symbolicTraits
        combined.formUnion(traits)
        let descriptor = fontDescriptor.withSymbolicTraits(combined)
        if let font = PlatformFont(descriptor: descriptor, size: pointSize) {
            return font
        }
        return self
        #endif
    }
}
