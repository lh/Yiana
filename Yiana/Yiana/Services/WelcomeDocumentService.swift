//
//  WelcomeDocumentService.swift
//  Yiana
//
//  Creates a welcome document for new users on first launch
//

import Foundation
import PDFKit
import YianaDocumentArchive
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WelcomeDocumentService {
    private static let hasCreatedWelcomeDocumentKey = "hasCreatedWelcomeDocument"

    /// Check if user needs a welcome document (first launch with no documents)
    static func shouldCreateWelcomeDocument(repository: DocumentRepository) -> Bool {
        // Only create when the library is empty
        let existingDocuments = repository.allDocumentsRecursive()
        return existingDocuments.isEmpty
    }

    /// Creates the welcome document in the user's documents folder
    static func createWelcomeDocument(repository: DocumentRepository) {
        // Mark as created (even if creation fails, don't retry)
        UserDefaults.standard.set(true, forKey: hasCreatedWelcomeDocumentKey)

        let documentURL = repository.newDocumentURL(title: "Welcome to Yiana")

        // Create welcome PDF
        guard let pdfData = createWelcomePDF() else {
            print("Failed to create welcome PDF")
            return
        }

        // Create metadata
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Welcome to Yiana",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: ["welcome", "getting-started"],
            ocrCompleted: true,
            fullText: welcomeText,
            hasPendingTextPage: false
        )

        // Encode metadata
        let encoder = JSONEncoder()
        guard let metadataData = try? encoder.encode(metadata) else {
            print("Failed to encode welcome document metadata")
            return
        }

        // Write document
        do {
            try DocumentArchive.write(
                metadata: metadataData,
                pdf: .data(pdfData),
                to: documentURL,
                formatVersion: DocumentArchive.currentFormatVersion
            )
            print("Created welcome document at: \(documentURL.path)")

            // Notify that documents changed
            NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
        } catch {
            print("Failed to write welcome document: \(error)")
        }
    }

    // MARK: - Private

    private static let welcomeText = """
    Welcome to Yiana

    Yiana is a document scanning and management app designed for easy organisation of your scanned documents.

    Getting Started

    Scan Documents
    Tap the + button and choose Scan to capture new documents using your device's camera. The scanner automatically detects page edges and enhances the image quality.

    Import Files
    You can also import existing PDFs or images from your device. Tap + and choose Import to select files.

    Organise with Folders
    Create folders to organise your documents. Long-press on the document list to access folder management options.

    Search
    Once documents are processed, you can search through their text content. The search finds matches across all your documents.

    iCloud Sync
    Your documents automatically sync across all your devices via iCloud. Changes made on one device appear on all others.

    Tips

    - Documents are stored as .yianazip files in your iCloud Drive
    - You can share documents directly from the app
    - Swipe left on a document to delete it
    - Tap and hold for more options

    For more information, visit the app settings or contact support.
    """

    private static func createWelcomePDF() -> Data? {
        // Create PDF with text content
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // Letter size
        let pdfData = NSMutableData()

        #if os(iOS)
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        UIGraphicsBeginPDFPage()

        let context = UIGraphicsGetCurrentContext()!

        // Draw content
        drawWelcomeContent(in: context, rect: pageRect)

        UIGraphicsEndPDFContext()
        #elseif os(macOS)
        // macOS PDF creation
        var mediaBox = pageRect

        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        context.beginPDFPage(nil)

        // Flip coordinate system for macOS
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)

        drawWelcomeContent(in: context, rect: pageRect)

        context.endPDFPage()
        context.closePDF()
        #endif

        return pdfData as Data
    }

    private static func drawWelcomeContent(in context: CGContext, rect: CGRect) {
        let margin: CGFloat = 50
        let contentRect = rect.insetBy(dx: margin, dy: margin)

        // Colors
        #if os(iOS)
        let titleColor = UIColor.label
        let textColor = UIColor.secondaryLabel
        let headingColor = UIColor.label
        #elseif os(macOS)
        let titleColor = NSColor.labelColor
        let textColor = NSColor.secondaryLabelColor
        let headingColor = NSColor.labelColor
        #endif

        var yPosition = contentRect.minY

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(size: 28, weight: .bold),
            .foregroundColor: titleColor
        ]
        let title = "Welcome to Yiana"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: CGPoint(x: contentRect.midX - titleSize.width / 2, y: yPosition), withAttributes: titleAttributes)
        yPosition += titleSize.height + 20

        // Subtitle
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(size: 14, weight: .regular),
            .foregroundColor: textColor
        ]
        let subtitle = "Your document scanning and management app"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        subtitle.draw(at: CGPoint(x: contentRect.midX - subtitleSize.width / 2, y: yPosition), withAttributes: subtitleAttributes)
        yPosition += subtitleSize.height + 40

        // Sections
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(size: 16, weight: .semibold),
            .foregroundColor: headingColor
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(size: 12, weight: .regular),
            .foregroundColor: textColor
        ]

        let sections: [(heading: String, body: String)] = [
            ("Scan Documents", "Tap the + button and choose Scan to capture new documents using your device's camera."),
            ("Import Files", "Import existing PDFs or images from your device by tapping + and choosing Import."),
            ("Organise with Folders", "Create folders to organise your documents. Long-press for folder management options."),
            ("Search", "Once documents are processed, search through their text content across all documents."),
            ("iCloud Sync", "Documents automatically sync across all your devices via iCloud.")
        ]

        for section in sections {
            // Heading
            section.heading.draw(at: CGPoint(x: contentRect.minX, y: yPosition), withAttributes: headingAttributes)
            yPosition += 22

            // Body - wrap text
            let bodyRect = CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: 60)
            let bodyString = NSAttributedString(string: section.body, attributes: bodyAttributes)
            bodyString.draw(in: bodyRect)
            yPosition += 50
        }

        // Footer
        yPosition = rect.maxY - margin - 30
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: platformFont(size: 10, weight: .regular),
            .foregroundColor: textColor
        ]
        let footer = "You can delete this document once you've read it."
        let footerSize = footer.size(withAttributes: footerAttributes)
        footer.draw(at: CGPoint(x: contentRect.midX - footerSize.width / 2, y: yPosition), withAttributes: footerAttributes)
    }

    #if os(iOS)
    private static func platformFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
    #elseif os(macOS)
    private static func platformFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
    #endif
}
