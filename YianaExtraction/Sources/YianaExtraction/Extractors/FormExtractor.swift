import Foundation

/// Extracts patient data from clinical correspondence with field labels
/// like "Patient name:", "Address:", "Date of birth:".
public struct FormExtractor: Extractor {

    public init() {}

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        let text = input.text
        let lines = text.components(separatedBy: "\n")

        // Step 1: Detect form structure — require at least one labelled field
        let hasNameLabel = lines.contains { line in
            let lower = line.lowercased()
            return lower.contains("patient name") || lower.contains("full name")
                || lower.contains("client name")
                || (lower.hasPrefix("name") && line.contains(":"))
        }
        let hasAddressLabel = lines.contains { line in
            let lower = line.lowercased()
            return lower.contains("address") && line.contains(":")
        }

        // Must have at least a name label to qualify as a form
        guard hasNameLabel else { return nil }

        // Step 2: Extract patient name
        var fullName: String?
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            let isNameLabel = lower.contains("patient name") || lower.contains("full name")
                || lower.contains("client name")
                || (lower.hasPrefix("name") && line.contains(":"))
            guard isNameLabel else { continue }

            // Check for value after colon on the same line
            if let colonRange = line.range(of: ":") {
                let after = line[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
                if !after.isEmpty {
                    fullName = ExtractionHelpers.cleanName(after)
                    break
                }
            }
            // Otherwise check the next non-empty line
            for j in (i + 1)..<min(i + 3, lines.count) {
                let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                if !nextLine.isEmpty && !nextLine.contains(":") {
                    fullName = ExtractionHelpers.cleanName(nextLine)
                    break
                }
            }
            if fullName != nil { break }
        }

        // Step 3: Date of birth
        var dob: String?
        for (i, line) in lines.enumerated() {
            let lower = line.lowercased()
            guard lower.contains("date of birth") || lower.contains("dob") else { continue }
            // Try current line
            if let date = ExtractionHelpers.extractDate(from: line) {
                dob = date
                break
            }
            // Try next line
            if i + 1 < lines.count, let date = ExtractionHelpers.extractDate(from: lines[i + 1]) {
                dob = date
                break
            }
            break
        }

        // Step 4: Address block — lines after "Address:" label up to postcode
        var postcode: String?
        var addressLines: [String] = []
        if hasAddressLabel {
            for (i, line) in lines.enumerated() {
                let lower = line.lowercased()
                guard lower.contains("address") && line.contains(":") else { continue }

                // Check if there's content after the colon on the same line
                if let colonRange = line.range(of: ":") {
                    let after = line[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
                    if !after.isEmpty {
                        addressLines.append(after)
                    }
                }

                for j in (i + 1)..<min(i + 7, lines.count) {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if nextLine.isEmpty { continue }
                    if nextLine.contains(":") { break }
                    // Stop at "Dear" or other letter markers
                    if nextLine.lowercased().hasPrefix("dear ") { break }
                    addressLines.append(nextLine)
                }

                // Find postcode in collected lines
                for addrLine in addressLines {
                    if let pc = ExtractionHelpers.firstPostcode(in: addrLine) {
                        postcode = pc
                        break
                    }
                }
                break
            }
        }

        // If no postcode from address block, try whole text
        if postcode == nil {
            postcode = ExtractionHelpers.firstPostcode(in: text)
        }

        // Extract city: line before postcode, then postcode-line text, then 3rd address line
        var city: String?
        if !addressLines.isEmpty, let pc = postcode {
            if let pcLineIdx = addressLines.firstIndex(where: {
                ExtractionHelpers.firstPostcode(in: $0) == pc
            }) {
                // Line before postcode
                if pcLineIdx >= 1 {
                    let candidate = addressLines[pcLineIdx - 1]
                    if !candidate.isEmpty, candidate.first?.isNumber != true {
                        city = candidate
                    }
                }
                // Text on same line as postcode (e.g. "London SW1A 1AA")
                if city == nil {
                    city = ExtractionHelpers.cityFromPostcodeLine(addressLines[pcLineIdx])
                }
            }
            // Third address line as fallback (line1=street, line2=area, line3=city)
            if city == nil, addressLines.count >= 3 {
                let candidate = addressLines[2]
                if !candidate.isEmpty,
                   candidate.first?.isNumber != true,
                   ExtractionHelpers.firstPostcode(in: candidate) == nil {
                    city = candidate
                }
            }
        }

        // Step 5: Validation — require both name and postcode
        guard fullName != nil, !fullName!.isEmpty, postcode != nil else { return nil }

        return AddressPageEntry(
            pageNumber: input.pageNumber,
            patient: PatientInfo(
                fullName: fullName,
                dateOfBirth: dob
            ),
            address: AddressInfo(city: city, postcode: postcode),
            extraction: ExtractionInfo(method: "form", confidence: 0.8),
            addressType: "patient"
        )
    }
}
