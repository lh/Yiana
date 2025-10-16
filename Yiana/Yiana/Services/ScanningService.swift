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
import CoreImage
import AVFoundation

/// Color mode options for scanning
enum ScanColorMode: String, CaseIterable {
    case color = "Color"
    case blackAndWhite = "Black & White"

    var description: String { rawValue }
}

/// Protocol defining scanning operations
protocol ScanningServiceProtocol {
    /// Check if scanning is available on this device
    func isScanningAvailable() -> Bool

    /// Convert an array of scanned images to PDF data
    func convertImagesToPDF(_ images: [UIImage]) async -> Data?

    /// Convert images to PDF with specified color mode
    func convertImagesToPDF(_ images: [UIImage], colorMode: ScanColorMode) async -> Data?
}

/// Mock implementation for development and testing
class MockScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        return true
    }

    func convertImagesToPDF(_ images: [UIImage]) async -> Data? {
        return await convertImagesToPDF(images, colorMode: .color)
    }

    func convertImagesToPDF(_ images: [UIImage], colorMode: ScanColorMode) async -> Data? {
        guard !images.isEmpty else { return nil }

        let preferredPaper = await TextPageLayoutSettings.shared.preferredPaperSize()
        let targetSize = preferredPaper.size
        let targetRect = CGRect(origin: .zero, size: targetSize)
        let contentRect = targetRect.insetBy(dx: 24, dy: 24)

        // Process images based on color mode
        let processedImages = colorMode == .blackAndWhite ?
            images.compactMap { convertToBlackAndWhite($0) } : images

        // Create a PDF from the images
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, targetRect, nil)

        for image in processedImages {
            UIGraphicsBeginPDFPageWithInfo(targetRect, nil)
            let drawRect = AVMakeRect(aspectRatio: image.size, insideRect: contentRect)
            image.draw(in: drawRect)
        }

        UIGraphicsEndPDFContext()
        return pdfData as Data
    }

    private func convertToBlackAndWhite(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        // Apply noir filter for black and white conversion
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)

        guard let outputImage = filter?.outputImage else { return image }

        // Increase contrast for better document scanning
        let contrastFilter = CIFilter(name: "CIColorControls")
        contrastFilter?.setValue(outputImage, forKey: kCIInputImageKey)
        contrastFilter?.setValue(1.1, forKey: kCIInputContrastKey)
        contrastFilter?.setValue(0, forKey: kCIInputSaturationKey)

        guard let finalImage = contrastFilter?.outputImage else { return image }

        let context = CIContext()
        guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else { return image }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Real implementation using VisionKit
class ScanningService: ScanningServiceProtocol {
    func isScanningAvailable() -> Bool {
        // Check if document scanning is supported
        return VNDocumentCameraViewController.isSupported
    }

    func convertImagesToPDF(_ images: [UIImage]) async -> Data? {
        return await convertImagesToPDF(images, colorMode: .color)
    }

    func convertImagesToPDF(_ images: [UIImage], colorMode: ScanColorMode) async -> Data? {
        guard !images.isEmpty else { return nil }

        let preferredPaper = await TextPageLayoutSettings.shared.preferredPaperSize()
        let targetSize = preferredPaper.size
        let targetRect = CGRect(origin: .zero, size: targetSize)
        let contentRect = targetRect.insetBy(dx: 24, dy: 24)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Process images based on color mode
                let processedImages = colorMode == .blackAndWhite ?
                    images.compactMap { ScanningService.convertToBlackAndWhite($0) } : images

                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, targetRect, nil)

                for image in processedImages {
                    UIGraphicsBeginPDFPageWithInfo(targetRect, nil)
                    let drawRect = AVMakeRect(aspectRatio: image.size, insideRect: contentRect)
                    image.draw(in: drawRect)
                }

                UIGraphicsEndPDFContext()
                continuation.resume(returning: pdfData as Data)
            }
        }
    }

    private static func convertToBlackAndWhite(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }

        // Apply noir filter for black and white conversion
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)

        guard let outputImage = filter?.outputImage else { return image }

        // Increase contrast for better document scanning
        let contrastFilter = CIFilter(name: "CIColorControls")
        contrastFilter?.setValue(outputImage, forKey: kCIInputImageKey)
        contrastFilter?.setValue(1.1, forKey: kCIInputContrastKey)
        contrastFilter?.setValue(0, forKey: kCIInputSaturationKey)
        contrastFilter?.setValue(0.05, forKey: kCIInputBrightnessKey)

        guard let finalImage = contrastFilter?.outputImage else { return image }

        // Apply sharpening for text clarity
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")
        sharpenFilter?.setValue(finalImage, forKey: kCIInputImageKey)
        sharpenFilter?.setValue(0.4, forKey: kCIInputSharpnessKey)

        guard let sharpImage = sharpenFilter?.outputImage else {
            let context = CIContext()
            guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else { return image }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(sharpImage, from: sharpImage.extent) else { return image }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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
