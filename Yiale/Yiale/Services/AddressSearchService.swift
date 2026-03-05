import Foundation

final class AddressSearchService {
    private var addressFiles: [DocumentAddressFile] = []
    private var resolvedPatients: [ResolvedPatient] = []

    /// Load all .addresses/*.json from the iCloud container.
    /// Call from Task.detached (file I/O off main thread).
    func loadAll() throws {
        guard let addressesURL = ICloudContainer.shared.addressesURL else {
            throw ServiceError.iCloudUnavailable
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: addressesURL.path) else {
            addressFiles = []
            resolvedPatients = []
            return
        }

        // No .skipsHiddenFiles — iCloud marks synced files as hidden
        let contents = try fm.contentsOfDirectory(
            at: addressesURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        let jsonFiles = contents.filter { $0.pathExtension == "json" }

        let decoder = JSONDecoder()
        var files: [DocumentAddressFile] = []
        for url in jsonFiles {
            do {
                let data = try Data(contentsOf: url)
                let file = try decoder.decode(DocumentAddressFile.self, from: data)
                files.append(file)
            } catch {
                #if DEBUG
                print("[AddressSearch] Failed to decode \(url.lastPathComponent): \(error)")
                #endif
            }
        }

        addressFiles = files
        resolvedPatients = files.map { ResolvedPatient(from: $0) }

        #if DEBUG
        print("[AddressSearch] Loaded \(resolvedPatients.count) patients from \(jsonFiles.count) files")
        #endif
    }

    /// Search patients by name or DOB. Case-insensitive substring match.
    func search(query: String) -> [ResolvedPatient] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return resolvedPatients.filter { patient in
            patient.fullName.lowercased().contains(q)
                || (patient.dateOfBirth?.contains(q) == true)
                || (patient.mrn?.lowercased().contains(q) == true)
        }
    }

    /// Get a specific patient by documentId.
    func patient(forDocument documentId: String) -> ResolvedPatient? {
        resolvedPatients.first { $0.documentId == documentId }
    }

    /// Get the raw address file for a document (needed for recipient address extraction).
    func addressFile(forDocument documentId: String) -> DocumentAddressFile? {
        addressFiles.first { $0.documentId == documentId }
    }

    var patientCount: Int { resolvedPatients.count }
}

enum ServiceError: LocalizedError {
    case iCloudUnavailable
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud container is not available"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}
