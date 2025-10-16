//
//  ScannerView.swift
//  Yiana
//
//  Created by Claude on 15/07/2025.
//

import SwiftUI
#if os(iOS)
import VisionKit
import UIKit

/// SwiftUI wrapper for VNDocumentCameraViewController
struct ScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onScanComplete: ([UIImage]) -> Void
    let onScanCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScannerView

        init(_ parent: ScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Extract all scanned pages as images
            var scannedImages: [UIImage] = []

            for pageIndex in 0..<scan.pageCount {
                let scannedImage = scan.imageOfPage(at: pageIndex)
                scannedImages.append(scannedImage)
            }

            parent.isPresented = false
            parent.onScanComplete(scannedImages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.isPresented = false
            parent.onScanCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            // Handle error same as cancel for now
            parent.isPresented = false
            parent.onScanCancel()
        }
    }
}

/// Helper view modifier to present the scanner
struct ScannerViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onScanComplete: ([UIImage]) -> Void
    let onScanCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                ScannerView(
                    isPresented: $isPresented,
                    onScanComplete: onScanComplete,
                    onScanCancel: onScanCancel
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Present a document scanner
    func documentScanner(
        isPresented: Binding<Bool>,
        onScanComplete: @escaping ([UIImage]) -> Void,
        onScanCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(ScannerViewModifier(
            isPresented: isPresented,
            onScanComplete: onScanComplete,
            onScanCancel: onScanCancel
        ))
    }
}
#endif
