import Foundation

/// Last-resort extractor for unstructured text: finds a title+name pattern
/// (Mr/Mrs/Ms/Dr/Prof) and a postcode anchor.
public struct FallbackExtractor: Extractor {

    public init() {}

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        let text = input.text

        // Step 1: Find UK postcode as anchor
        guard let postcode = ExtractionHelpers.firstPostcode(in: text) else { return nil }

        // Step 2: Find title+name pattern — strip the title prefix
        var fullName: String?
        if let m = ExtractionHelpers.firstMatch(
            #"(?:Mr|Mrs|Ms|Miss|Dr|Prof)\.?\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)"#,
            in: text
        ) {
            fullName = ExtractionHelpers.cleanName(m[1])
        }

        guard let name = fullName, !name.isEmpty else { return nil }

        // Step 3: Find any date
        let dob = ExtractionHelpers.extractDate(from: text)

        // Step 4: City — find the postcode line and strip the postcode
        var city: String?
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.uppercased().contains(postcode) {
                city = ExtractionHelpers.cityFromPostcodeLine(line)
                break
            }
        }
        if city == nil {
            city = ExtractionHelpers.townForPostcode(postcode)
        }

        return AddressPageEntry(
            pageNumber: input.pageNumber,
            patient: PatientInfo(
                fullName: name,
                dateOfBirth: dob
            ),
            address: AddressInfo(city: city, postcode: postcode),
            extraction: ExtractionInfo(method: "unstructured", confidence: 0.5),
            addressType: "patient"
        )
    }
}
