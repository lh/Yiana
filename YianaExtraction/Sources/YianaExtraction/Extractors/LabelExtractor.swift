import Foundation

/// Extracts patient data from unstructured address blocks:
/// name on the first line, address lines, postcode.
public struct LabelExtractor: Extractor {

    public init() {}

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        let text = input.text
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        // Slide a window starting from each line index
        for startIdx in 0..<lines.count {
            let windowEnd = min(startIdx + 6, lines.count)
            let window = Array(lines[startIdx..<windowEnd])

            // Find first line in window containing a UK postcode
            var postcodeIdx: Int?
            for (wi, wline) in window.enumerated() {
                if ExtractionHelpers.firstPostcode(in: wline) != nil {
                    postcodeIdx = wi
                    break
                }
            }

            guard let pcIdx = postcodeIdx else { continue }

            // First line of window = name candidate
            let nameCandidate = window[0]

            // Skip if first line looks like a postcode itself (name must be separate)
            if ExtractionHelpers.firstPostcode(in: nameCandidate) != nil && pcIdx == 0 {
                continue
            }

            // Skip if first line looks like a header/boilerplate
            let lower = nameCandidate.lowercased()
            if lower.hasPrefix("dear ") || lower.hasPrefix("ref:") || lower.hasPrefix("confidential")
                || lower.contains("department") || lower.contains("registration")
                || lower.contains("clearwater") || lower.contains("clinical")
                || lower.contains("patient") {
                continue
            }

            // Skip if first line looks like a number-prefixed address line
            if nameCandidate.first?.isNumber == true {
                continue
            }

            let postcode = ExtractionHelpers.firstPostcode(in: window[pcIdx])!
            let fullName = ExtractionHelpers.cleanName(nameCandidate)

            guard !fullName.isEmpty else { continue }

            // Look for DOB nearby
            var dob: String?
            // Check lines after the postcode within a few lines
            let searchEnd = min(startIdx + pcIdx + 3, lines.count)
            for si in (startIdx + pcIdx + 1)..<searchEnd {
                if let date = ExtractionHelpers.extractDate(from: lines[si]) {
                    dob = date
                    break
                }
            }
            // Also check a DOB label near the window
            for wline in window {
                let wlower = wline.lowercased()
                if wlower.contains("dob") || wlower.contains("date of birth") {
                    if let date = ExtractionHelpers.extractDate(from: wline) {
                        dob = date
                        break
                    }
                }
            }

            // Extract city from the line before the postcode
            var city: String?
            if pcIdx >= 2 {
                // Lines between name (0) and postcode (pcIdx): address block
                let cityCandidate = window[pcIdx - 1]
                // Only use it if it doesn't look like a street address (no house number prefix)
                if !cityCandidate.isEmpty,
                   cityCandidate.first?.isNumber != true,
                   ExtractionHelpers.firstPostcode(in: cityCandidate) == nil {
                    city = cityCandidate
                }
            }

            return AddressPageEntry(
                pageNumber: input.pageNumber,
                patient: PatientInfo(
                    fullName: fullName,
                    dateOfBirth: dob
                ),
                address: AddressInfo(city: city, postcode: postcode),
                extraction: ExtractionInfo(method: "label", confidence: 0.7),
                addressType: "patient"
            )
        }

        return nil
    }
}
