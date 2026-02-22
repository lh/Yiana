import Foundation
import PDFKit
import Vision

/// Result of on-device OCR processing
struct OnDeviceOCRResult {
    let fullText: String
    let confidence: Double
    let pageCount: Int

    static let empty = OnDeviceOCRResult(fullText: "", confidence: 0, pageCount: 0)
}

/// On-device OCR using Vision framework's VNRecognizeTextRequest.
/// Processes pages sequentially to cap memory usage on mobile devices.
final class OnDeviceOCRService {
    static let shared = OnDeviceOCRService()

    /// Render scale for PDF→CGImage conversion. Matches backend's 3x for best accuracy.
    private let renderScale: CGFloat = 3.0

    private init() {}

    /// Recognize text in a PDF document.
    /// - Parameter pdfData: Raw PDF bytes
    /// - Returns: Concatenated text, average confidence, and page count
    func recognizeText(in pdfData: Data) async -> OnDeviceOCRResult {
        guard let document = PDFDocument(data: pdfData) else {
            return .empty
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else { return .empty }

        var pageTexts: [String] = []
        var totalConfidence: Double = 0

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            let (text, confidence) = await processPage(page)
            if !text.isEmpty {
                pageTexts.append(text)
            }
            totalConfidence += confidence
        }

        let fullText = pageTexts.joined(separator: "\n\n")
        let avgConfidence = pageCount > 0 ? totalConfidence / Double(pageCount) : 0

        return OnDeviceOCRResult(
            fullText: fullText,
            confidence: avgConfidence,
            pageCount: pageCount
        )
    }

    // MARK: - Private

    private func processPage(_ page: PDFPage) async -> (String, Double) {
        guard let image = renderPageToImage(page) else {
            return ("", 0)
        }

        do {
            let observations = try await performTextRecognition(on: image)
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            let confidence = observations.isEmpty ? 0.0 :
                observations.map { Double($0.confidence) }.reduce(0, +) / Double(observations.count)
            return (text, confidence)
        } catch {
            return ("", 0)
        }
    }

    private func performTextRecognition(on image: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                continuation.resume(returning: observations)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func renderPageToImage(_ page: PDFPage) -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scaledWidth = Int(pageRect.width * renderScale)
        let scaledHeight = Int(pageRect.height * renderScale)

        guard scaledWidth > 0, scaledHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        // White background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        // Draw the PDF page
        context.saveGState()
        context.scaleBy(x: renderScale, y: renderScale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }
}
