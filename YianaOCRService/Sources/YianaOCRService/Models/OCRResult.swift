import Foundation
import Vision

/// Represents the complete OCR result for a document
public struct OCRResult: Codable {
    /// Unique identifier for this OCR operation
    let id: UUID
    
    /// Timestamp when OCR was performed
    let processedAt: Date
    
    /// Document identifier (from the original document)
    let documentId: UUID
    
    /// OCR engine version for tracking
    let engineVersion: String
    
    /// Pages in the document
    let pages: [OCRPage]
    
    /// Full text extracted from all pages
    var fullText: String {
        pages.map { $0.text }.joined(separator: "\n\n")
    }
    
    /// Structured data extracted from forms (if any)
    var extractedData: ExtractedFormData?
    
    /// Confidence score (0-1)
    let confidence: Double
    
    /// Processing metadata
    let metadata: ProcessingMetadata
}

/// Represents OCR results for a single page
public struct OCRPage: Codable {
    /// Page number (1-based, page 1 is the first page)
    let pageNumber: Int
    
    /// Full text of the page
    let text: String
    
    /// Text blocks with position information
    let textBlocks: [TextBlock]
    
    /// Detected form fields on this page
    var formFields: [FormField]?
    
    /// Page-level confidence score
    let confidence: Double
}

/// Represents a block of text with position information
public struct TextBlock: Codable {
    /// The recognized text
    let text: String
    
    /// Bounding box in normalized coordinates (0-1)
    let boundingBox: BoundingBox
    
    /// Confidence score for this text block
    let confidence: Double
    
    /// Text lines within this block
    let lines: [TextLine]
}

/// Represents a single line of text
public struct TextLine: Codable {
    /// The text content
    let text: String
    
    /// Bounding box in normalized coordinates
    let boundingBox: BoundingBox
    
    /// Words in this line
    let words: [Word]
}

/// Represents a single word
public struct Word: Codable {
    /// The word text
    let text: String
    
    /// Bounding box in normalized coordinates
    let boundingBox: BoundingBox
    
    /// Confidence score
    let confidence: Double
}

/// Bounding box in normalized coordinates (0-1)
public struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    /// Convert from Vision's normalized rect
    init(from visionRect: CGRect) {
        // Vision uses bottom-left origin, we'll use top-left
        self.x = visionRect.origin.x
        self.y = 1.0 - (visionRect.origin.y + visionRect.height)
        self.width = visionRect.width
        self.height = visionRect.height
    }
    
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Extracted structured data from forms
public struct ExtractedFormData: Codable {
    /// Demographic information
    var demographics: Demographics?
    
    /// Key-value pairs extracted from forms
    var fields: [String: String]
    
    /// Custom extracted entities
    var entities: [ExtractedEntity]
    
    /// Extraction confidence
    let confidence: Double
}

/// Demographics data structure
public struct Demographics: Codable {
    var firstName: String?
    var lastName: String?
    var dateOfBirth: String?
    var gender: String?
    var address: Address?
    var phoneNumber: String?
    var email: String?
    var identificationNumber: String?
    
    /// Medical-specific fields
    var medicalRecordNumber: String?
    var insuranceId: String?
    var provider: String?
}

/// Address structure
public struct Address: Codable {
    var street: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?
}

/// Generic extracted entity
public struct ExtractedEntity: Codable {
    /// Entity type (e.g., "DATE", "PERSON", "ORGANIZATION")
    let type: String
    
    /// The extracted value
    let value: String
    
    /// Confidence score
    let confidence: Double
    
    /// Location in the document
    let location: TextLocation?
}

/// Location of text in document
public struct TextLocation: Codable {
    let pageNumber: Int
    let boundingBox: BoundingBox
}

/// Form field detected in the document
public struct FormField: Codable {
    /// Field label/name
    let label: String
    
    /// Field value
    let value: String
    
    /// Field type (text, checkbox, signature, etc.)
    let fieldType: FieldType
    
    /// Position in the page
    let boundingBox: BoundingBox
    
    /// Confidence score
    let confidence: Double
}

/// Types of form fields
public enum FieldType: String, Codable {
    case text
    case checkbox
    case radio
    case signature
    case date
    case number
    case email
    case phone
}

/// Processing metadata
public struct ProcessingMetadata: Codable {
    /// Processing duration in seconds
    let processingTime: TimeInterval
    
    /// Number of pages processed
    let pageCount: Int
    
    /// Language detected
    let detectedLanguages: [String]
    
    /// Any warnings or issues during processing
    let warnings: [String]
    
    /// Processing options used
    let options: ProcessingOptions
}

/// Options for OCR processing
public struct ProcessingOptions: Codable {
    /// Recognition level (fast vs accurate)
    let recognitionLevel: RecognitionLevel
    
    /// Languages to recognize
    let languages: [String]
    
    /// Whether to use language correction
    let useLanguageCorrection: Bool
    
    /// Whether to extract form data
    let extractFormData: Bool
    
    /// Whether to detect demographics
    let extractDemographics: Bool
    
    /// Custom revision data hints
    let customDataHints: [String]?
    
    static let `default` = ProcessingOptions(
        recognitionLevel: .accurate,
        languages: ["en-US"],
        useLanguageCorrection: true,
        extractFormData: false,
        extractDemographics: false,
        customDataHints: nil
    )
}

/// Recognition accuracy level
public enum RecognitionLevel: String, Codable {
    case fast
    case accurate
}