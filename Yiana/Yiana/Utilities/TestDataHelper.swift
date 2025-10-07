//
//  TestDataHelper.swift
//  Yiana
//
//  Test helper for creating sample documents with OCR data
//

#if DEBUG
import Foundation
import PDFKit

struct TestDataHelper {
    static func createTestDocumentWithOCR() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.vitygas.Yiana", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)
        
        // Create test document
        let testDocURL = documentsPath.appendingPathComponent("OCR-Test-\(UUID().uuidString.prefix(8)).yianazip")
        
        // Create sample PDF
        let pdfDocument = PDFDocument()
        let page = PDFPage()
        pdfDocument.insert(page, at: 0)
        let pdfData = pdfDocument.dataRepresentation() ?? Data()
        
        // Create metadata with OCR data
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "OCR Test Document",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: ["test", "ocr", "sample"],
            ocrCompleted: true,
            fullText: """
            PATIENT INFORMATION
            Name: John Doe
            Date of Birth: 01/15/1980
            MRN: 123456789
            
            CHIEF COMPLAINT
            Patient presents with persistent headache lasting 3 days.
            
            HISTORY OF PRESENT ILLNESS
            The patient reports the headache started gradually three days ago. 
            It is described as a throbbing pain, primarily located in the frontal region.
            Pain intensity is rated 7/10. Associated symptoms include mild nausea 
            and photophobia. No fever or neck stiffness reported.
            
            PAST MEDICAL HISTORY
            - Hypertension (diagnosed 2018)
            - Type 2 Diabetes Mellitus (diagnosed 2020)
            - Seasonal allergies
            
            MEDICATIONS
            - Metformin 1000mg BID
            - Lisinopril 10mg daily
            - Loratadine 10mg PRN
            
            ALLERGIES
            NKDA (No Known Drug Allergies)
            
            PHYSICAL EXAMINATION
            Vital Signs:
            - BP: 130/85 mmHg
            - HR: 78 bpm
            - Temp: 98.6°F
            - RR: 16/min
            - O2 Sat: 98% on room air
            
            General: Alert and oriented x3, in mild distress due to headache
            HEENT: Pupils equal, round, and reactive to light. No papilledema.
            Cardiovascular: Regular rate and rhythm, no murmurs
            Respiratory: Clear to auscultation bilaterally
            Neurological: Cranial nerves II-XII intact, no focal deficits
            
            ASSESSMENT AND PLAN
            Primary headache disorder, likely tension-type headache vs migraine.
            - Prescribed Sumatriptan 50mg for acute episodes
            - Recommend headache diary
            - Follow up in 2 weeks
            - Consider MRI if symptoms persist or worsen
            
            Provider: Dr. Jane Smith, MD
            Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))
            """,
            hasPendingTextPage: false
        )
        
        // Encode metadata
        let encoder = JSONEncoder()
        let metadataData = try! encoder.encode(metadata)
        
        // Combine into document format
        var documentData = Data()
        documentData.append(metadataData)
        documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        documentData.append(pdfData)
        
        // Write to file
        try! documentData.write(to: testDocURL)
        
        print("✅ Created test document with OCR at: \(testDocURL.path)")
        
        // Post notification to refresh document list
        NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
    }
    
    static func createTestDocumentWithoutOCR() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.vitygas.Yiana", isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)
        
        // Create test document
        let testDocURL = documentsPath.appendingPathComponent("No-OCR-Test-\(UUID().uuidString.prefix(8)).yianazip")
        
        // Create sample PDF
        let pdfDocument = PDFDocument()
        let page = PDFPage()
        pdfDocument.insert(page, at: 0)
        let pdfData = pdfDocument.dataRepresentation() ?? Data()
        
        // Create metadata without OCR data
        let metadata = DocumentMetadata(
            id: UUID(),
            title: "Document Pending OCR",
            created: Date(),
            modified: Date(),
            pageCount: 1,
            tags: ["test", "pending"],
            ocrCompleted: false,
            fullText: nil,
            hasPendingTextPage: false
        )
        
        // Encode metadata
        let encoder = JSONEncoder()
        let metadataData = try! encoder.encode(metadata)
        
        // Combine into document format
        var documentData = Data()
        documentData.append(metadataData)
        documentData.append(Data([0xFF, 0xFF, 0xFF, 0xFF])) // Separator
        documentData.append(pdfData)
        
        // Write to file
        try! documentData.write(to: testDocURL)
        
        print("✅ Created test document without OCR at: \(testDocURL.path)")
        
        // Post notification to refresh document list
        NotificationCenter.default.post(name: .yianaDocumentsChanged, object: nil)
    }
}
#endif
