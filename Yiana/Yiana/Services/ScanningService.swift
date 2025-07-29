//
//  ScanningService.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import Foundation
#if os(iOS)
import UIKit
import VisionKit

/// Protocol defining scanning operations
protocol ScanningServiceProtocol {
    /// Check if scanning is available on this device
    func isScanningAvailable() -> Bool
    
    /// Convert an array of scanned images to PDF data
    func convertImagesToPDF(_ images: [UIImage]) async -> Data?
}

/// Mock implementation for development and testing
class MockScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        return true
    }
    
    func convertImagesToPDF(_ images: [UIImage]) async -> Data? {
        guard !images.isEmpty else { return nil }
        
        // Create a PDF from the images
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

/// Real implementation using VisionKit
class ScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        // Check if document scanning is supported
        return VNDocumentCameraViewController.isSupported
    }
    
    func convertImagesToPDF(_ images: [UIImage]) async -> Data? {
        guard !images.isEmpty else { return nil }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
                
                for image in images {
                    // Calculate page size to fit A4 aspect ratio
                    let a4AspectRatio: CGFloat = 297.0 / 210.0
                    let imageAspectRatio = image.size.height / image.size.width
                    
                    let pageSize: CGSize
                    if imageAspectRatio > a4AspectRatio {
                        // Image is taller than A4
                        pageSize = CGSize(width: 612, height: 612 * imageAspectRatio)
                    } else {
                        // Image is wider than A4
                        pageSize = CGSize(width: 792 / imageAspectRatio, height: 792)
                    }
                    
                    let pageRect = CGRect(origin: .zero, size: pageSize)
                    UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
                    
                    // Draw image to fill the page
                    image.draw(in: pageRect)
                }
                
                UIGraphicsEndPDFContext()
                continuation.resume(returning: pdfData as Data)
            }
        }
    }
}

#else

// macOS stub implementation
protocol ScanningServiceProtocol {
    func isScanningAvailable() -> Bool
}

class ScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        return false
    }
}

class MockScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        return false
    }
}

#endif