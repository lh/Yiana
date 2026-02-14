import Foundation
import PDFKit
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
}

