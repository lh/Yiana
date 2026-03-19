import Foundation
import GRDB

/// Looks up GP practices by postcode from the NHS ODS database.
///
/// Supports exact postcode matching with optional district-level fallback
/// when hints are provided. Ported from the Python `NHSLookup` class.
public struct NHSLookupService: Sendable {
    private let dbQueue: DatabaseQueue

    /// Initialise with path to nhs_lookup.db.
    public init(databasePath: String) throws {
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: databasePath, configuration: config)
    }

    /// Look up GP practices by postcode, with optional hint-based scoring.
    ///
    /// Algorithm:
    /// 1. Exact postcode match — return all active practices.
    /// 2. If no exact match and at least one hint is provided, fall back to
    ///    postcode district and score candidates by name/address similarity.
    /// 3. If a name hint is provided for exact matches, reorder so
    ///    name-matched practices come first.
    public func lookupGP(
        postcode: String,
        nameHint: String? = nil,
        addressHint: String? = nil
    ) throws -> [NHSCandidate] {
        let (spaced, district) = normalisePostcode(postcode)

        // 1. Exact postcode match
        var practices = try dbQueue.read { db in
            try GPPractice
                .filter(Column("postcode") == spaced && Column("status") == "Active")
                .fetchAll(db)
        }

        // 2. District fallback if no exact match and we have hints
        if practices.isEmpty, nameHint != nil || addressHint != nil {
            let candidates = try dbQueue.read { db in
                try GPPractice
                    .filter(Column("postcode_district") == district && Column("status") == "Active")
                    .fetchAll(db)
            }

            if !candidates.isEmpty {
                var scored = candidates.map { candidate in
                    (score: scoreMatch(candidate, nameHint: nameHint, addressHint: addressHint), practice: candidate)
                }
                scored.sort { $0.score < $1.score }

                let bestScore = scored[0].score
                if bestScore <= 7, scored.count == 1 || scored[1].score > bestScore + 2 {
                    practices = [scored[0].practice]
                } else {
                    practices = Array(scored.prefix(2).map(\.practice))
                }
            }
        }

        // 3. Hint reordering for exact matches
        if let nameHint, !practices.isEmpty {
            let hintLower = nameHint.lowercased()
            practices.sort { a, b in
                let aMatches = a.name.lowercased().contains(hintLower)
                let bMatches = b.name.lowercased().contains(hintLower)
                if aMatches != bMatches { return aMatches }
                return a.name < b.name
            }
        }

        return practices.map(makeCandidate)
    }

    // MARK: - Private

    private static let nameStopWords: Set<String> = [
        "the", "surgery", "practice", "medical", "centre", "center", "group", "dr",
    ]

    private static let addressStopWords: Set<String> = [
        "the", "road", "street", "lane", "avenue", "close", "drive",
    ]

    /// Normalise a UK postcode. Returns (spaced, district).
    private func normalisePostcode(_ postcode: String) -> (spaced: String, district: String) {
        let normalised = postcode.uppercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
        if normalised.count >= 5 {
            let splitIndex = normalised.index(normalised.endIndex, offsetBy: -3)
            let outward = String(normalised[normalised.startIndex..<splitIndex])
            let inward = String(normalised[splitIndex...])
            return (outward + " " + inward, outward)
        }
        return (normalised, normalised)
    }

    /// Score a practice against hints. Lower is better.
    private func scoreMatch(_ practice: GPPractice, nameHint: String?, addressHint: String?) -> Int {
        var score = 10
        let name = practice.name.lowercased()
        let addr = practice.addressLine1.lowercased()

        if let nameHint {
            let words = nameHint.lowercased().split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !Self.nameStopWords.contains($0) }
            for word in words {
                if name.contains(word) { score -= 3 }
            }
        }

        if let addressHint {
            let words = addressHint.lowercased().split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 && !Self.addressStopWords.contains($0) }
            for word in words {
                if name.contains(word) || addr.contains(word) { score -= 3 }
            }
        }

        return score
    }

    /// Convert a GPPractice record to the public NHSCandidate type.
    private func makeCandidate(from practice: GPPractice) -> NHSCandidate {
        NHSCandidate(
            source: "gp",
            odsCode: practice.odsCode,
            name: practice.name,
            addressLine1: practice.addressLine1,
            town: practice.town,
            postcode: practice.postcode
        )
    }
}
