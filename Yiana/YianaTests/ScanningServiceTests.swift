//
//  ScanningServiceTests.swift
//  YianaTests
//
//  Created by Claude on 15/07/2025.
//

import XCTest
@testable import Yiana
#if os(iOS)
import UIKit

final class ScanningServiceTests: XCTestCase {
    
    func testScanningServiceProtocol() {
        // Test that the protocol exists and has required methods
        let mockService = MockScanningService()
        
        // Test availability check
        XCTAssertTrue(mockService.isScanningAvailable())
    }
    
    func testConvertImagesToPDF() async {
        let mockService = MockScanningService()
        
        // Create test images
        let testImages: [UIImage] = [
            createTestImage(color: .red),
            createTestImage(color: .blue),
            createTestImage(color: .green)
        ]
        
        // Convert to PDF
        let pdfData = await mockService.convertImagesToPDF(testImages)
        
        // Verify PDF data is not nil and has content
        XCTAssertNotNil(pdfData)
        XCTAssertGreaterThan(pdfData?.count ?? 0, 0)
    }
    
    func testConvertEmptyImageArray() async {
        let mockService = MockScanningService()
        
        // Convert empty array
        let pdfData = await mockService.convertImagesToPDF([])
        
        // Should return nil for empty array
        XCTAssertNil(pdfData)
    }
    
    func testConvertSingleImageToPDF() async {
        let mockService = MockScanningService()
        
        // Create single test image
        let testImage = createTestImage(color: .yellow)
        
        // Convert to PDF
        let pdfData = await mockService.convertImagesToPDF([testImage])
        
        // Verify PDF data
        XCTAssertNotNil(pdfData)
        XCTAssertGreaterThan(pdfData?.count ?? 0, 0)
    }
    
    // Helper function to create test images
    private func createTestImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
}

// Mock implementation for testing
class MockScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        return true
    }
    
    func convertImagesToPDF(_ images: [UIImage]) async -> Data? {
        return await convertImagesToPDF(images, colorMode: .color)
    }

    func convertImagesToPDF(_ images: [UIImage], colorMode: ScanColorMode) async -> Data? {
        guard !images.isEmpty else { return nil }

        // Create a simple PDF
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
        
        for image in images {
            let pageRect = CGRect(origin: .zero, size: image.size)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
            image.draw(in: pageRect)
        }
        
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
}
#endif