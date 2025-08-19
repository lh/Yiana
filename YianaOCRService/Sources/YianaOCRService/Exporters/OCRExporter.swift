import Foundation

/// Protocol for exporting OCR results to different formats
public protocol OCRExporter {
    func export(_ result: OCRResult) throws -> Data
    var fileExtension: String { get }
    var mimeType: String { get }
}

/// Exports OCR results as JSON
public struct JSONExporter: OCRExporter {
    public var fileExtension: String { "json" }
    public var mimeType: String { "application/json" }
    
    private let encoder: JSONEncoder
    
    public init(prettyPrint: Bool = true) {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
    }
    
    public func export(_ result: OCRResult) throws -> Data {
        try encoder.encode(result)
    }
}

/// Exports OCR results as XML
public struct XMLExporter: OCRExporter {
    public var fileExtension: String { "xml" }
    public var mimeType: String { "application/xml" }
    
    public func export(_ result: OCRResult) throws -> Data {
        let xml = buildXML(from: result)
        guard let data = xml.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
    
    private func buildXML(from result: OCRResult) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <OCRResult>
            <DocumentId>\(result.documentId)</DocumentId>
            <ProcessedAt>\(ISO8601DateFormatter().string(from: result.processedAt))</ProcessedAt>
            <EngineVersion>\(result.engineVersion)</EngineVersion>
            <Confidence>\(result.confidence)</Confidence>
            <Pages>
        """
        
        for page in result.pages {
            xml += """
            
                <Page number="\(page.pageNumber)">
                    <Text><![CDATA[\(page.text)]]></Text>
                    <Confidence>\(page.confidence)</Confidence>
            """
            
            if let formFields = page.formFields {
                xml += "\n        <FormFields>"
                for field in formFields {
                    xml += """
                    
                            <Field type="\(field.fieldType.rawValue)">
                                <Label>\(escapeXML(field.label))</Label>
                                <Value>\(escapeXML(field.value))</Value>
                                <Confidence>\(field.confidence)</Confidence>
                            </Field>
                    """
                }
                xml += "\n        </FormFields>"
            }
            
            xml += "\n    </Page>"
        }
        
        if let extractedData = result.extractedData {
            xml += "\n    <ExtractedData>"
            
            if let demographics = extractedData.demographics {
                xml += buildDemographicsXML(demographics)
            }
            
            if !extractedData.fields.isEmpty {
                xml += "\n        <Fields>"
                for (key, value) in extractedData.fields {
                    xml += """
                    
                            <Field name="\(escapeXML(key))">\(escapeXML(value))</Field>
                    """
                }
                xml += "\n        </Fields>"
            }
            
            xml += "\n    </ExtractedData>"
        }
        
        xml += """
        
            </Pages>
        </OCRResult>
        """
        
        return xml
    }
    
    private func buildDemographicsXML(_ demographics: Demographics) -> String {
        var xml = "\n        <Demographics>"
        
        if let firstName = demographics.firstName {
            xml += "\n            <FirstName>\(escapeXML(firstName))</FirstName>"
        }
        if let lastName = demographics.lastName {
            xml += "\n            <LastName>\(escapeXML(lastName))</LastName>"
        }
        if let dob = demographics.dateOfBirth {
            xml += "\n            <DateOfBirth>\(escapeXML(dob))</DateOfBirth>"
        }
        if let gender = demographics.gender {
            xml += "\n            <Gender>\(escapeXML(gender))</Gender>"
        }
        if let phone = demographics.phoneNumber {
            xml += "\n            <PhoneNumber>\(escapeXML(phone))</PhoneNumber>"
        }
        if let email = demographics.email {
            xml += "\n            <Email>\(escapeXML(email))</Email>"
        }
        
        if let address = demographics.address {
            xml += "\n            <Address>"
            if let street = address.street {
                xml += "\n                <Street>\(escapeXML(street))</Street>"
            }
            if let city = address.city {
                xml += "\n                <City>\(escapeXML(city))</City>"
            }
            if let state = address.state {
                xml += "\n                <State>\(escapeXML(state))</State>"
            }
            if let zip = address.postalCode {
                xml += "\n                <PostalCode>\(escapeXML(zip))</PostalCode>"
            }
            xml += "\n            </Address>"
        }
        
        xml += "\n        </Demographics>"
        return xml
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Exports OCR results as hOCR (HTML-based OCR format)
public struct HOCRExporter: OCRExporter {
    public var fileExtension: String { "hocr" }
    public var mimeType: String { "text/html" }
    
    public func export(_ result: OCRResult) throws -> Data {
        let html = buildHOCR(from: result)
        guard let data = html.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return data
    }
    
    private func buildHOCR(from result: OCRResult) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="ocr-system" content="YianaOCR \(result.engineVersion)">
            <meta name="ocr-capabilities" content="ocr_page ocr_carea ocr_par ocr_line ocr_word">
            <title>OCR Result - \(result.documentId)</title>
        </head>
        <body>
        """
        
        for page in result.pages {
            let pageId = "page_\(page.pageNumber + 1)"
            html += """
            
            <div class="ocr_page" id="\(pageId)" title="bbox 0 0 1000 1000">
            """
            
            for (blockIndex, block) in page.textBlocks.enumerated() {
                let blockId = "\(pageId)_block_\(blockIndex + 1)"
                let bbox = convertBBox(block.boundingBox)
                
                html += """
                
                <div class="ocr_carea" id="\(blockId)" title="bbox \(bbox)">
                """
                
                for (lineIndex, line) in block.lines.enumerated() {
                    let lineId = "\(blockId)_line_\(lineIndex + 1)"
                    let lineBbox = convertBBox(line.boundingBox)
                    
                    html += """
                    
                    <span class="ocr_line" id="\(lineId)" title="bbox \(lineBbox)">
                    """
                    
                    for (wordIndex, word) in line.words.enumerated() {
                        let wordId = "\(lineId)_word_\(wordIndex + 1)"
                        let wordBbox = convertBBox(word.boundingBox)
                        let confidence = Int(word.confidence * 100)
                        
                        html += """
                        <span class="ocrx_word" id="\(wordId)" title="bbox \(wordBbox); x_wconf \(confidence)">\(escapeHTML(word.text))</span>
                        """
                        
                        if wordIndex < line.words.count - 1 {
                            html += " "
                        }
                    }
                    
                    html += "</span>"
                }
                
                html += "\n</div>"
            }
            
            html += "\n</div>"
        }
        
        html += """
        
        </body>
        </html>
        """
        
        return html
    }
    
    private func convertBBox(_ bbox: BoundingBox) -> String {
        // Convert normalized coordinates to pixel coordinates (assuming 1000x1000 canvas)
        let x1 = Int(bbox.x * 1000)
        let y1 = Int(bbox.y * 1000)
        let x2 = Int((bbox.x + bbox.width) * 1000)
        let y2 = Int((bbox.y + bbox.height) * 1000)
        return "\(x1) \(y1) \(x2) \(y2)"
    }
    
    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Export errors
public enum ExportError: Error, LocalizedError {
    case encodingFailed
    case invalidFormat
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode OCR result"
        case .invalidFormat:
            return "Invalid export format"
        }
    }
}