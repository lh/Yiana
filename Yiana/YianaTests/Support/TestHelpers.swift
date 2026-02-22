import Foundation
import PDFKit
import CoreText
@testable import Yiana
#if os(iOS)
import UIKit
#endif

// MARK: - Compatibility shim for stale tests referencing removed property
extension DocumentListViewModel {
    var documentURLs: [URL] { documents.map(\.url) }
}

enum TempDir {
    static func makeUnique(subpath: String = UUID().uuidString) throws -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("YianaTests", isDirectory: true)
        let url = base.appendingPathComponent(subpath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

enum TestPDFFactory {
    /// Create a simple multi-page PDF as Data
    static func makePDFData(pageCount: Int) -> Data {
        precondition(pageCount > 0)
        #if os(iOS)
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        for i in 1...pageCount {
            let size = CGSize(width: 595, height: 842) // A4-ish
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: size), nil)
            // Draw small page label
            let text = "Test Page \(i)"
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            text.draw(at: CGPoint(x: 20, y: 20), withAttributes: attrs)
        }
        UIGraphicsEndPDFContext()
        return pdfData as Data
        #else
        // Fallback using PDFKit only (macOS tests)
        let doc = PDFDocument()
        for _ in 0..<pageCount {
            let page = PDFPage()
            doc.insert(page, at: doc.pageCount)
        }
        return doc.dataRepresentation() ?? Data()
        #endif
    }

    /// Create a PDF with large, OCR-readable text on each page.
    /// Uses Core Text directly so it works on both iOS and macOS without UIKit.
    static func makePDFWithText(_ texts: [String], fontSize: CGFloat = 36) -> Data {
        let pageSize = CGSize(width: 595, height: 842)
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        for text in texts {
            var mediaBox = CGRect(origin: .zero, size: pageSize)
            context.beginPage(mediaBox: &mediaBox)

            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            ]
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            let textRect = CGRect(x: 40, y: 40, width: pageSize.width - 80, height: pageSize.height - 80)
            let path = CGPath(rect: textRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, context)

            context.endPage()
        }

        context.closePDF()
        return data as Data
    }
}

