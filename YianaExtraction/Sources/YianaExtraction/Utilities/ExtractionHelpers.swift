import Foundation

/// Shared regex and text-processing helpers used across extractors.
enum ExtractionHelpers {

    // MARK: - Regex

    /// Returns capture groups for the first match, or nil.
    /// Index 0 = full match, 1+ = capture groups.
    static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange) else { return nil }
        var result: [String] = []
        for i in 0..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: text) {
                result.append(String(text[range]))
            } else {
                result.append("")
            }
        }
        return result
    }

    /// Returns all matches as arrays of capture groups.
    static func allMatches(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).map { match in
            (0..<match.numberOfRanges).map { i in
                if let range = Range(match.range(at: i), in: text) {
                    return String(text[range])
                }
                return ""
            }
        }
    }

    // MARK: - Postcode

    /// First UK-format postcode found in text.
    static func firstPostcode(in text: String) -> String? {
        let upper = text.uppercased()
        let matches = allMatches(#"([A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2})"#, in: upper)
        for groups in matches {
            let pc = groups[1]
            if firstMatch(#"^[A-Z]{1,2}\d{1,2}[A-Z]?\s*\d[A-Z]{2}$"#, in: pc) != nil {
                return pc
            }
        }
        return nil
    }

    // MARK: - Name Cleaning

    /// Remove non-alpha characters (keep spaces, hyphens, apostrophes), normalize whitespace, title case.
    static func cleanName(_ raw: String) -> String {
        // Remove anything that isn't a letter, space, hyphen, or apostrophe
        let cleaned = raw.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar)
                || scalar == " "
                || scalar == "-"
                || scalar == "'"
        }
        let str = String(String.UnicodeScalarView(cleaned))
        // Normalize whitespace
        let parts = str.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return "" }
        // Title case each part
        return parts.map { word in
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    // MARK: - Date Extraction

    /// Tries common date patterns: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY,
    /// DD/MM/YY, DD Month YYYY.
    /// Returns the date as DD/MM/YYYY if found, nil otherwise.
    static func extractDate(from text: String) -> String? {
        // DD/MM/YYYY, DD.MM.YYYY, or DD-MM-YYYY (4-digit year)
        if let m = firstMatch(#"(\d{1,2})[./-](\d{1,2})[./-](\d{4})"#, in: text) {
            return "\(m[1])/\(m[2])/\(m[3])"
        }
        // DD/MM/YY, DD.MM.YY, or DD-MM-YY (2-digit year)
        if let m = firstMatch(#"(\d{1,2})[./-](\d{1,2})[./-](\d{2})\b"#, in: text) {
            let yy = Int(m[3]) ?? 0
            let yyyy = yy >= 30 ? "19\(m[3])" : "20\(m[3])"
            return "\(m[1])/\(m[2])/\(yyyy)"
        }
        // DD Month YYYY
        if let m = firstMatch(
            #"(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})"#,
            in: text, options: [.caseInsensitive]
        ) {
            let months = ["january": "01", "february": "02", "march": "03", "april": "04",
                          "may": "05", "june": "06", "july": "07", "august": "08",
                          "september": "09", "october": "10", "november": "11", "december": "12"]
            if let mm = months[m[2].lowercased()] {
                return "\(m[1])/\(mm)/\(m[3])"
            }
        }
        return nil
    }
}
