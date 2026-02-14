import SwiftUI
import UniformTypeIdentifiers

/// Payload for dragging documents within and out of Yiana.
///
/// Uses manual NSItemProvider construction instead of Transferable because
/// macOS doesn't reliably register custom UTTypes from DerivedData builds
/// in LaunchServices, causing CodableRepresentation to silently fail.
///
/// In-app drag detection uses a static `inFlight` property rather than
/// pasteboard type sniffing, because SwiftUI's DropInfo returns proxy
/// providers with empty `registeredTypeIdentifiers`.
struct DocumentDragItem: Codable {
    let id: UUID
    let documentURL: URL

    /// Set when an in-app drag starts, read by the drop delegate, cleared after drop.
    static var inFlight: DocumentDragItem?

    /// UTType identifier string (kept for the NSItemProvider registration).
    static let internalTypeID = "com.vitygas.yiana.drag-item"

    /// Creates an NSItemProvider with PDF for external drops (Finder, Mail, etc.)
    /// and stores `self` in `inFlight` for in-app folder drop detection.
    func makeItemProvider() -> NSItemProvider {
        Self.inFlight = self

        let provider = NSItemProvider()

        // External: PDF file for cross-app drops
        let sourceURL = documentURL
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.pdf.identifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            do {
                let tempURL = try ExportService().createTemporaryPDF(from: sourceURL)
                completion(tempURL, false, nil)
            } catch {
                completion(nil, false, error)
            }
            return nil
        }

        return provider
    }
}

extension UTType {
    static let yianaDragItem = UTType(exportedAs: "com.vitygas.yiana.drag-item")
}
