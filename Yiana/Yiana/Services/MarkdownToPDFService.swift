//
//  MarkdownToPDFService.swift
//  Yiana
//
//  Service to convert markdown text to PDF pages
//

import UIKit
import PDFKit

class MarkdownToPDFService {

    // MARK: - Configuration

    enum PageSize {
        case usLetter
        case a4

        var cgSize: CGSize {
            switch self {
            case .usLetter:
                return CGSize(width: 612, height: 792) // 8.5 x 11 inches at 72 DPI
            case .a4:
                return CGSize(width: 595, height: 842) // 210 x 297 mm at 72 DPI
            }
        }
    }

    private let pageSize: PageSize
    private let margins: UIEdgeInsets
    private let headerHeight: CGFloat = 30

    init(pageSize: PageSize = .usLetter) {
        self.pageSize = pageSize
        // 1 inch margins (72 points) on all sides for ~6 inch text column
        self.margins = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
    }

    // MARK: - Public API

    /// Convert markdown text to PDF data
    func renderToPDF(markdown: String, addedDate: Date = Date()) -> Data? {
        let attributedString = parseMarkdown(markdown)
        return createPDF(from: attributedString, addedDate: addedDate)
    }

    // MARK: - Markdown Parsing

    private func parseMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        let defaultFont = UIFont.systemFont(ofSize: 12)
        let boldFont = UIFont.boldSystemFont(ofSize: 12)
        let h1Font = UIFont.boldSystemFont(ofSize: 20)
        let h2Font = UIFont.boldSystemFont(ofSize: 16)
        let h3Font = UIFont.boldSystemFont(ofSize: 14)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8

        for line in lines {
            var processedLine = line
            var attributes: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .paragraphStyle: paragraphStyle
            ]

            // Headers
            if processedLine.hasPrefix("### ") {
                processedLine = String(processedLine.dropFirst(4))
                attributes[.font] = h3Font
            } else if processedLine.hasPrefix("## ") {
                processedLine = String(processedLine.dropFirst(3))
                attributes[.font] = h2Font
            } else if processedLine.hasPrefix("# ") {
                processedLine = String(processedLine.dropFirst(2))
                attributes[.font] = h1Font
            }
            // Blockquotes
            else if processedLine.hasPrefix("> ") {
                processedLine = String(processedLine.dropFirst(2))
                let quoteParagraph = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                quoteParagraph.firstLineHeadIndent = 20
                quoteParagraph.headIndent = 20
                attributes[.paragraphStyle] = quoteParagraph
                attributes[.foregroundColor] = UIColor.darkGray
            }
            // Unordered lists
            else if processedLine.hasPrefix("- ") || processedLine.hasPrefix("* ") {
                processedLine = "• " + String(processedLine.dropFirst(2))
                let listParagraph = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                listParagraph.firstLineHeadIndent = 0
                listParagraph.headIndent = 20
                attributes[.paragraphStyle] = listParagraph
            }
            // Ordered lists (simple detection)
            else if processedLine.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                let listParagraph = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                listParagraph.firstLineHeadIndent = 0
                listParagraph.headIndent = 20
                attributes[.paragraphStyle] = listParagraph
            }
            // Horizontal rules
            else if processedLine == "---" || processedLine == "***" {
                processedLine = "\n"
                // Add a line after this
                let line = NSAttributedString(string: processedLine + "\n", attributes: attributes)
                result.append(line)
                continue
            }

            // Process inline markdown (bold and italic)
            let mutableLine = NSMutableAttributedString(string: processedLine, attributes: attributes)

            // Bold
            let boldPattern = #"\*\*(.*?)\*\*"#
            if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
                let matches = boldRegex.matches(in: processedLine, range: NSRange(location: 0, length: processedLine.count))
                for match in matches.reversed() {
                    if match.range(at: 1).location != NSNotFound,
                   let range = Range(match.range(at: 1), in: processedLine) {
                        let boldText = String(processedLine[range])
                        let nsRange = match.range(at: 0)
                        mutableLine.replaceCharacters(in: nsRange, with: boldText)
                        mutableLine.addAttribute(.font, value: boldFont, range: NSRange(location: nsRange.location, length: boldText.count))
                    }
                }
            }

            // Italic
            let italicPattern = #"\*(.*?)\*"#
            if let italicRegex = try? NSRegularExpression(pattern: italicPattern) {
                let currentString = mutableLine.string
                let matches = italicRegex.matches(in: currentString, range: NSRange(location: 0, length: currentString.count))
                for match in matches.reversed() {
                    if match.range(at: 1).location != NSNotFound,
                   let range = Range(match.range(at: 1), in: currentString) {
                        let italicText = String(currentString[range])
                        let nsRange = match.range(at: 0)
                        mutableLine.replaceCharacters(in: nsRange, with: italicText)

                        // Create italic font
                        var traits = UIFontDescriptor.SymbolicTraits()
                        traits.insert(.traitItalic)
                        if let currentFont = mutableLine.attribute(.font, at: max(0, nsRange.location - 1), effectiveRange: nil) as? UIFont,
                           let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                            let italicFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                            mutableLine.addAttribute(.font, value: italicFont, range: NSRange(location: nsRange.location, length: italicText.count))
                        }
                    }
                }
            }

            mutableLine.append(NSAttributedString(string: "\n"))
            result.append(mutableLine)
        }

        return result
    }

    // MARK: - PDF Creation

    private func createPDF(from attributedString: NSAttributedString, addedDate: Date) -> Data? {
        let pageRect = CGRect(origin: .zero, size: pageSize.cgSize)
        let contentRect = CGRect(
            x: margins.left,
            y: margins.top + headerHeight,
            width: pageRect.width - margins.left - margins.right,
            height: pageRect.height - margins.top - margins.bottom - headerHeight
        )

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            // Draw header
            drawHeader(in: context, pageRect: pageRect, date: addedDate)

            // Draw content
            var currentY: CGFloat = contentRect.minY
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            var currentIndex = 0
            let totalLength = attributedString.length

            while currentIndex < totalLength {
                let remainingRect = CGRect(
                    x: contentRect.minX,
                    y: currentY,
                    width: contentRect.width,
                    height: contentRect.maxY - currentY
                )

                let path = CGPath(rect: remainingRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRangeMake(currentIndex, 0),
                    path,
                    nil
                )

                CTFrameDraw(frame, context.cgContext)

                let visibleRange = CTFrameGetVisibleStringRange(frame)
                currentIndex = visibleRange.location + visibleRange.length

                if currentIndex < totalLength {
                    // Need a new page
                    context.beginPage()
                    drawHeader(in: context, pageRect: pageRect, date: addedDate)
                    currentY = contentRect.minY
                } else {
                    break
                }
            }
        }
    }

    private func drawHeader(in context: UIGraphicsPDFRendererContext, pageRect: CGRect, date: Date) {
        let headerText = "Inserted note — \(formatDate(date))"
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]

        let headerSize = headerText.size(withAttributes: headerAttributes)
        let headerRect = CGRect(
            x: margins.left,
            y: margins.top - 20,
            width: pageRect.width - margins.left - margins.right,
            height: headerSize.height
        )

        headerText.draw(in: headerRect, withAttributes: headerAttributes)

        // Draw a separator line
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: margins.left, y: margins.top))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width - margins.right, y: margins.top))
        context.cgContext.strokePath()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}