//
//  TextPagePDFRenderer.swift
//  Yiana
//
//  Created by GPT-5 Codex on 12/01/2026.
//
//  Renders Markdown content into a single PDF page (with spillover support)
//  using a consistent layout tuned for medical note appendices. The renderer
//  applies the same typography on both iOS and macOS, producing data suitable
//  for appending to an existing PDF document.
//

import Foundation
import CoreGraphics
import PDFKit

#if os(iOS)
import UIKit
#else
import AppKit
#endif

private extension NSAttributedString.Key {
    static var yianaInlinePresentation: NSAttributedString.Key {
        if #available(iOS 15.0, macOS 12.0, *) {
            return NSAttributedString.Key("NSInlinePresentationIntentAttributeName")
        } else {
            return NSAttributedString.Key("NSInlinePresentationIntentAttributeName")
        }
    }

    static var yianaPresentation: NSAttributedString.Key {
        if #available(iOS 15.0, macOS 12.0, *) {
            return NSAttributedString.Key("NSPresentationIntentAttributeName")
        } else {
            return NSAttributedString.Key("NSPresentationIntentAttributeName")
        }
    }
}

struct TextPageRenderOutput {
    let pdfData: Data
    let plainText: String
}

struct TextPageRenderOptions {
    var paperSize: CGSize
    var insets: TextPageEdgeInsets
    var headerFont: PlatformFont
    var bodyFont: PlatformFont
    var boldFont: PlatformFont
    var italicFont: PlatformFont
    var monoFont: PlatformFont
    var headerColor: PlatformColor
    var bodyColor: PlatformColor
    var secondaryColor: PlatformColor
    var accentColor: PlatformColor
    var lineSpacing: CGFloat
    var paragraphSpacing: CGFloat
    var headerSpacing: CGFloat

    static func `default`(for paperSize: TextPagePaperSize) -> TextPageRenderOptions {
        let size = paperSize.size
        let columnWidth: CGFloat = 432 // 6 inches at 72 DPI
        let horizontalPadding = max(24, (size.width - columnWidth) / 2)
        let insets = TextPageEdgeInsets(top: 72, left: horizontalPadding, bottom: 64, right: horizontalPadding)

        #if os(iOS)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let headerFont = UIFont.preferredFont(forTextStyle: .headline).withSize(bodyFont.pointSize * 0.9)
        let boldFont = UIFont(descriptor: bodyFont.fontDescriptor.withSymbolicTraits(.traitBold) ?? bodyFont.fontDescriptor, size: bodyFont.pointSize)
        let italicFont = UIFont(descriptor: bodyFont.fontDescriptor.withSymbolicTraits(.traitItalic) ?? bodyFont.fontDescriptor, size: bodyFont.pointSize)
        let monoFont = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize * 0.95, weight: .regular)
        let headerColor = UIColor.darkGray
        let bodyColor = UIColor.black
        let secondaryColor = UIColor.gray
        let accentColor = TextPageBrand.accentColor
        #else
        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let headerFont = NSFont.preferredFont(forTextStyle: .headline)
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(bodyFont, toHaveTrait: .boldFontMask)
        let italicFont = fontManager.convert(bodyFont, toHaveTrait: .italicFontMask)
        let monoFont = NSFont.monospacedSystemFont(ofSize: bodyFont.pointSize * 0.95, weight: .regular)
        let headerColor = NSColor.secondaryLabelColor
        let bodyColor = NSColor.textColor
        let secondaryColor = NSColor.secondaryLabelColor
        let accentColor = TextPageBrand.accentColor
        #endif

        return TextPageRenderOptions(
            paperSize: size,
            insets: insets,
            headerFont: headerFont,
            bodyFont: bodyFont,
            boldFont: boldFont,
            italicFont: italicFont,
            monoFont: monoFont,
            headerColor: headerColor,
            bodyColor: bodyColor,
            secondaryColor: secondaryColor,
            accentColor: accentColor,
            lineSpacing: 4,
            paragraphSpacing: bodyFont.pointSize * 0.5,
            headerSpacing: 24
        )
    }
}

struct TextPageEdgeInsets {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat
}

final class TextPagePDFRenderer {

    func render(markdown: String, headerText: String, options: TextPageRenderOptions) throws -> TextPageRenderOutput {
        let markdownResult = makeBodyAttributedString(from: markdown, options: options)
        let bodyAttributed = markdownResult.attributed
        let fullPlainText = headerText + "\n\n" + markdownResult.plainText

        #if os(iOS)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: options.paperSize))
        let data = renderer.pdfData { context in
            context.beginPage()
            drawContent(
                context: context.cgContext,
                attributedString: bodyAttributed,
                header: headerText,
                options: options,
                beginNewPage: {
                    context.beginPage()
                }
            )
        }
        #else
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            throw NSError(domain: "TextPagePDFRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate PDF consumer"])
        }
        var mediaBox = CGRect(origin: .zero, size: options.paperSize)
        guard let cgContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TextPagePDFRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        cgContext.beginPDFPage(nil)
        drawContent(
            context: cgContext,
            attributedString: bodyAttributed,
            header: headerText,
            options: options,
            beginNewPage: {
                cgContext.beginPDFPage(nil)
            }
        )
        cgContext.endPDFPage()
        cgContext.closePDF()
        #endif

        return TextPageRenderOutput(pdfData: data as Data, plainText: fullPlainText)
    }

    private func drawContent(
        context cgContext: CGContext,
        attributedString: NSAttributedString,
        header: String,
        options: TextPageRenderOptions,
        beginNewPage: () -> Void
    ) {
        let headerHeight = lineHeight(for: options.headerFont)
        let textRect = textBoundingRect(options: options, headerHeight: headerHeight)

        drawHeader(header, in: cgContext, options: options, headerHeight: headerHeight)
        drawBody(attributedString, header: header, in: cgContext, textRect: textRect, options: options, beginNewPage: beginNewPage)
    }

    private func drawHeader(_ header: String, in context: CGContext, options: TextPageRenderOptions, headerHeight: CGFloat) {
        let headerRectTop = CGRect(
            x: options.insets.left,
            y: options.insets.top,
            width: options.paperSize.width - options.insets.left - options.insets.right,
            height: headerHeight
        )

        #if os(iOS)
        let headerRect = CGRect(
            x: options.insets.left,
            y: options.insets.top,
            width: options.paperSize.width - options.insets.left - options.insets.right,
            height: headerHeight
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: options.headerFont,
            .foregroundColor: options.headerColor
        ]
        (header as NSString).draw(in: headerRect, withAttributes: attributes)

        let separatorY = headerRect.maxY + 6
        let path = UIBezierPath()
        path.move(to: CGPoint(x: options.insets.left, y: separatorY))
        path.addLine(to: CGPoint(x: options.paperSize.width - options.insets.right, y: separatorY))
        path.lineWidth = 0.5
        options.secondaryColor.withAlphaComponent(0.35).setStroke()
        path.stroke()
        #else
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: options.paperSize.height)
        context.scaleBy(x: 1, y: -1)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: options.headerFont,
            .foregroundColor: options.headerColor
        ]
        (header as NSString).draw(in: headerRectTop, withAttributes: attributes)

        let separatorY = headerRectTop.maxY + 6
        context.setStrokeColor(options.secondaryColor.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: options.insets.left, y: separatorY))
        context.addLine(to: CGPoint(x: options.paperSize.width - options.insets.right, y: separatorY))
        context.strokePath()

        context.restoreGState()
        #endif
    }

    private func drawBody(
        _ attributedString: NSAttributedString,
        header: String,
        in context: CGContext,
        textRect: CGRect,
        options: TextPageRenderOptions,
        beginNewPage: () -> Void
    ) {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        var currentRange = CFRange(location: 0, length: 0)

        while currentRange.location < attributedString.length {
            let path = CGMutablePath()
            path.addRect(textRect)

            let frame = CTFramesetterCreateFrame(framesetter, currentRange, path, nil)
            let visibleRange = CTFrameGetVisibleStringRange(frame)

            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: options.paperSize.height)
            context.scaleBy(x: 1, y: -1)
            CTFrameDraw(frame, context)
            context.restoreGState()
#if DEBUG
            print("DEBUG TextPagePDFRenderer: drew range length = \(visibleRange.length)")
#endif

            currentRange.location += visibleRange.length
            if visibleRange.length == 0 {
                break
            }

            if currentRange.location < attributedString.length {
                beginNewPage()
                drawHeader(header, in: context, options: options, headerHeight: lineHeight(for: options.headerFont))
            }
        }
    }

    private func textBoundingRect(options: TextPageRenderOptions, headerHeight: CGFloat) -> CGRect {
        CGRect(
            x: options.insets.left,
            y: options.insets.bottom,
            width: options.paperSize.width - options.insets.left - options.insets.right,
            height: options.paperSize.height - options.insets.bottom - options.insets.top - headerHeight - options.headerSpacing
        )
    }

    private func makeBodyAttributedString(from markdown: String, options: TextPageRenderOptions) -> TextPageMarkdownFormatter.Result {
        if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return TextPageMarkdownFormatter.Result(attributed: NSAttributedString(string: ""), plainText: "")
        }

        let typography = TextPageTypography.current()
        let headingFonts = typography.headingFonts

        let styles = TextPageMarkdownFormatter.Styles(
            bodyFont: options.bodyFont,
            headingFonts: headingFonts,
            boldFont: options.boldFont,
            italicFont: options.italicFont,
            monoFont: options.monoFont,
            bodyColor: options.bodyColor,
            secondaryColor: options.secondaryColor,
            accentColor: options.accentColor,
            lineSpacing: options.lineSpacing,
            paragraphSpacing: options.paragraphSpacing,
            headingSpacing: options.headerSpacing,
            listIndent: 24,
            blockquoteIndent: 24
        )

        return TextPageMarkdownFormatter.makePDFBody(from: markdown, styles: styles)
    }

    private func headingFont(for level: Int, base: PlatformFont) -> PlatformFont {
        let clamped = max(1, min(level, 3))
        let sizeMultiplier: CGFloat
        switch clamped {
        case 1: sizeMultiplier = 1.4
        case 2: sizeMultiplier = 1.2
        default: sizeMultiplier = 1.1
        }
        let targetSize = base.pointSize * sizeMultiplier
        #if os(iOS)
        return UIFont(descriptor: base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor, size: targetSize)
        #else
        return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        #endif
    }

    private func lineHeight(for font: PlatformFont) -> CGFloat {
        #if os(iOS)
        return font.lineHeight
        #else
        return font.ascender - font.descender + font.leading
        #endif
    }
}
