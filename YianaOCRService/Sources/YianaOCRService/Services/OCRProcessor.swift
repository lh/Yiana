import Foundation
import Vision
import PDFKit
import Logging
import CoreGraphics

/// Processes documents for OCR using Vision framework
public class OCRProcessor {
    private let logger: Logger
    private let queue = DispatchQueue(label: "com.vitygas.yiana.ocr.processor", attributes: .concurrent)
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    /// Process a document with default options
    public func processDocument(_ document: YianaDocument) async throws -> OCRResult {
        return try await processDocument(document, options: .default)
    }
    
    /// Process a document with specific options
    public func processDocument(_ document: YianaDocument, options: ProcessingOptions) async throws -> OCRResult {
        let startTime = Date()
        
        guard let pdfData = document.pdfData else {
            throw OCRError.noPDFData
        }
        
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw OCRError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        logger.info("Starting OCR processing", metadata: [
            "pages": .stringConvertible(pageCount),
            "documentId": .string(document.metadata.id.uuidString)
        ])
        
        // Process pages
        let pages = try await processPages(pdfDocument, options: options)
        
        // Calculate overall confidence
        let overallConfidence = pages.isEmpty ? 0.0 : 
            pages.map { $0.confidence }.reduce(0.0, +) / Double(pages.count)
        
        // Extract structured data if requested
        var extractedData: ExtractedFormData?
        if options.extractFormData || options.extractDemographics {
            extractedData = try await extractStructuredData(from: pages, options: options)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Detect languages
        let detectedLanguages = detectLanguages(from: pages)
        
        let metadata = ProcessingMetadata(
            processingTime: processingTime,
            pageCount: pageCount,
            detectedLanguages: detectedLanguages,
            warnings: [],
            options: options
        )
        
        let result = OCRResult(
            id: UUID(),
            processedAt: Date(),
            documentId: document.metadata.id,
            engineVersion: "1.0.0",
            pages: pages,
            extractedData: extractedData,
            confidence: overallConfidence,
            metadata: metadata
        )
        
        logger.info("OCR processing completed", metadata: [
            "processingTime": .stringConvertible(processingTime),
            "confidence": .stringConvertible(overallConfidence)
        ])
        
        return result
    }
    
    private func processPages(_ pdfDocument: PDFDocument, options: ProcessingOptions) async throws -> [OCRPage] {
        var pages: [OCRPage] = []
        
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Pass 1-based page number to processPage
            let ocrPage = try await processPage(page, pageNumber: pageIndex + 1, options: options)
            pages.append(ocrPage)
            
            logger.debug("Processed page", metadata: [
                "pageNumber": .stringConvertible(pageIndex + 1),
                "confidence": .stringConvertible(ocrPage.confidence)
            ])
        }
        
        return pages
    }
    
    private func processPage(_ page: PDFPage, pageNumber: Int, options: ProcessingOptions) async throws -> OCRPage {
        // Convert PDF page to image
        let image = try renderPageToImage(page)
        
        // Create Vision request
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.recognitionLevel == .accurate ? .accurate : .fast
        request.recognitionLanguages = options.languages
        request.usesLanguageCorrection = options.useLanguageCorrection
        
        // Process the image
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        // Convert observations to our model
        let textBlocks = convertObservations(observations)
        
        // Extract full text
        let fullText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        
        // Calculate page confidence
        let pageConfidence = observations.isEmpty ? 0.0 :
            observations.map { Double($0.confidence) }.reduce(0.0, +) / Double(observations.count)
        
        // Extract form fields if requested
        var formFields: [FormField]?
        if options.extractFormData {
            formFields = extractFormFields(from: observations)
        }
        
        return OCRPage(
            pageNumber: pageNumber,
            text: fullText,
            textBlocks: textBlocks,
            formFields: formFields,
            confidence: pageConfidence
        )
    }
    
    private func renderPageToImage(_ page: PDFPage) throws -> CGImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3.0 // High resolution for better OCR
        let scaledWidth = Int(pageRect.width * scale)
        let scaledHeight = Int(pageRect.height * scale)
        
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
            throw OCRError.imageRenderingFailed
        }
        
        // White background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        
        // Draw the PDF page
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        
        guard let image = context.makeImage() else {
            throw OCRError.imageRenderingFailed
        }
        
        return image
    }
    
    private func convertObservations(_ observations: [VNRecognizedTextObservation]) -> [TextBlock] {
        observations.map { observation in
            let topCandidate = observation.topCandidates(1).first
            let text = topCandidate?.string ?? ""
            let confidence = observation.confidence
            
            // Convert bounding box
            let boundingBox = BoundingBox(from: observation.boundingBox)
            
            // Extract lines and words
            let lines = extractLines(from: observation)
            
            return TextBlock(
                text: text,
                boundingBox: boundingBox,
                confidence: Double(confidence),
                lines: lines
            )
        }
    }
    
    private func extractLines(from observation: VNRecognizedTextObservation) -> [TextLine] {
        guard let candidate = observation.topCandidates(1).first else { return [] }
        
        // Get character boxes if available
        guard let _ = try? candidate.boundingBox(for: candidate.string.startIndex..<candidate.string.endIndex) else {
            // Fallback: create single line
            return [TextLine(
                text: candidate.string,
                boundingBox: BoundingBox(from: observation.boundingBox),
                words: extractWords(from: candidate.string, boundingBox: BoundingBox(from: observation.boundingBox))
            )]
        }
        
        // Split into lines based on newlines
        let lines = candidate.string.components(separatedBy: .newlines)
        var textLines: [TextLine] = []
        
        for line in lines where !line.isEmpty {
            // Estimate line bounding box
            let lineBoundingBox = BoundingBox(from: observation.boundingBox) // Simplified
            let words = extractWords(from: line, boundingBox: lineBoundingBox)
            
            textLines.append(TextLine(
                text: line,
                boundingBox: lineBoundingBox,
                words: words
            ))
        }
        
        return textLines
    }
    
    private func extractWords(from text: String, boundingBox: BoundingBox) -> [Word] {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Estimate word positions (simplified - would need character-level boxes for accuracy)
        let wordWidth = boundingBox.width / Double(words.count)
        
        return words.enumerated().map { index, word in
            let wordBox = BoundingBox(
                x: boundingBox.x + (Double(index) * wordWidth),
                y: boundingBox.y,
                width: wordWidth,
                height: boundingBox.height
            )
            
            return Word(
                text: word,
                boundingBox: wordBox,
                confidence: 1.0 // Would need per-word confidence from Vision
            )
        }
    }
    
    private func extractFormFields(from observations: [VNRecognizedTextObservation]) -> [FormField] {
        var fields: [FormField] = []
        
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            
            // Simple heuristic: look for label:value patterns
            if text.contains(":") {
                let components = text.components(separatedBy: ":")
                if components.count == 2 {
                    let label = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                    
                    let fieldType = detectFieldType(for: value)
                    
                    fields.append(FormField(
                        label: label,
                        value: value,
                        fieldType: fieldType,
                        boundingBox: BoundingBox(from: observation.boundingBox),
                        confidence: Double(observation.confidence)
                    ))
                }
            }
        }
        
        return fields
    }
    
    private func detectFieldType(for value: String) -> FieldType {
        // Simple type detection
        if value.contains("@") && value.contains(".") {
            return .email
        } else if value.range(of: #"^\d{3}-\d{3}-\d{4}$"#, options: .regularExpression) != nil {
            return .phone
        } else if value.range(of: #"^\d{1,2}/\d{1,2}/\d{2,4}$"#, options: .regularExpression) != nil {
            return .date
        } else if Double(value) != nil {
            return .number
        } else {
            return .text
        }
    }
    
    private func extractStructuredData(from pages: [OCRPage], options: ProcessingOptions) async throws -> ExtractedFormData {
        var fields: [String: String] = [:]
        var entities: [ExtractedEntity] = []
        var demographics: Demographics?
        
        // Combine text from all pages
        let fullText = pages.map { $0.text }.joined(separator: "\n")
        
        // Extract fields from form fields
        for page in pages {
            if let formFields = page.formFields {
                for field in formFields {
                    fields[field.label] = field.value
                }
            }
        }
        
        // Extract demographics if requested
        if options.extractDemographics {
            demographics = extractDemographics(from: fullText, fields: fields)
        }
        
        // Extract entities using NLP
        entities = await extractEntities(from: fullText)
        
        let confidence = fields.isEmpty ? 0.5 : 0.75 // Simplified confidence
        
        return ExtractedFormData(
            demographics: demographics,
            fields: fields,
            entities: entities,
            confidence: confidence
        )
    }
    
    private func extractDemographics(from text: String, fields: [String: String]) -> Demographics {
        var demographics = Demographics()
        
        // Try to extract from form fields first
        for (label, value) in fields {
            let lowercaseLabel = label.lowercased()
            
            if lowercaseLabel.contains("first name") || lowercaseLabel.contains("fname") {
                demographics.firstName = value
            } else if lowercaseLabel.contains("last name") || lowercaseLabel.contains("lname") {
                demographics.lastName = value
            } else if lowercaseLabel.contains("date of birth") || lowercaseLabel.contains("dob") {
                demographics.dateOfBirth = value
            } else if lowercaseLabel.contains("gender") || lowercaseLabel.contains("sex") {
                demographics.gender = value
            } else if lowercaseLabel.contains("phone") || lowercaseLabel.contains("tel") {
                demographics.phoneNumber = value
            } else if lowercaseLabel.contains("email") {
                demographics.email = value
            } else if lowercaseLabel.contains("medical record") || lowercaseLabel.contains("mrn") {
                demographics.medicalRecordNumber = value
            } else if lowercaseLabel.contains("insurance") {
                demographics.insuranceId = value
            }
        }
        
        // Extract address if found
        demographics.address = extractAddress(from: fields)
        
        return demographics
    }
    
    private func extractAddress(from fields: [String: String]) -> Address? {
        var address = Address()
        var hasAddress = false
        
        for (label, value) in fields {
            let lowercaseLabel = label.lowercased()
            
            if lowercaseLabel.contains("street") || lowercaseLabel.contains("address") {
                address.street = value
                hasAddress = true
            } else if lowercaseLabel.contains("city") {
                address.city = value
                hasAddress = true
            } else if lowercaseLabel.contains("state") {
                address.state = value
                hasAddress = true
            } else if lowercaseLabel.contains("zip") || lowercaseLabel.contains("postal") {
                address.postalCode = value
                hasAddress = true
            } else if lowercaseLabel.contains("country") {
                address.country = value
                hasAddress = true
            }
        }
        
        return hasAddress ? address : nil
    }
    
    private func extractEntities(from text: String) async -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        
        // Simple regex-based entity extraction
        // Dates
        let dateRegex = try? NSRegularExpression(pattern: #"\d{1,2}/\d{1,2}/\d{2,4}"#)
        if let matches = dateRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(
                        type: "DATE",
                        value: String(text[range]),
                        confidence: 0.8,
                        location: nil
                    ))
                }
            }
        }
        
        // Phone numbers
        let phoneRegex = try? NSRegularExpression(pattern: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#)
        if let matches = phoneRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(
                        type: "PHONE",
                        value: String(text[range]),
                        confidence: 0.9,
                        location: nil
                    ))
                }
            }
        }
        
        // Email addresses
        let emailRegex = try? NSRegularExpression(pattern: #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
        if let matches = emailRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(
                        type: "EMAIL",
                        value: String(text[range]),
                        confidence: 0.95,
                        location: nil
                    ))
                }
            }
        }
        
        return entities
    }
    
    private func detectLanguages(from pages: [OCRPage]) -> [String] {
        // For now, return default language
        // Could use NLLanguageRecognizer for better detection
        return ["en-US"]
    }
    
    /// Embed OCR text as an invisible layer in the PDF
    public func embedTextLayer(in pdfData: Data, with ocrResult: OCRResult) throws -> Data {
        // For now, just return the original PDF data
        // The text layer embedding is causing issues with text selection
        // We'll keep the OCR results in metadata and separate files for search
        
        logger.info("Text layer embedding temporarily disabled", metadata: [
            "reason": .string("Preserving native PDF text selection")
        ])
        
        return pdfData
    }
    
    private func addInvisibleTextToPage(_ page: PDFPage, ocrData: OCRPage) {
        // This method is temporarily disabled
        // Widget annotations were interfering with text selection
    }
}

/// OCR processing errors
public enum OCRError: Error, LocalizedError {
    case noPDFData
    case invalidPDF
    case imageRenderingFailed
    case noTextFound
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noPDFData:
            return "No PDF data found in document"
        case .invalidPDF:
            return "Invalid PDF format"
        case .imageRenderingFailed:
            return "Failed to render PDF page to image"
        case .noTextFound:
            return "No text found in document"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
}