//
//  RegistrationFormExtractor.swift
//  YianaExtraction
//
//  Extracts data from structured registration forms (e.g. hospital intake forms).
//  Highest priority extractor — fires first in the cascade.
//  Ported from Python SpireFormExtractor.
//

import Foundation

public struct RegistrationFormExtractor: Extractor {

    /// Text markers that identify this form type.
    /// Both members of at least one pair must appear in the text.
    let triggers: [(String, String)] = [
        ("Spire Healthcare", "Registration Form"),
        ("Clearwater Medical", "Registration Form"),
    ]

    public init() {}

    public func extract(from input: ExtractionInput) -> AddressPageEntry? {
        let text = input.text

        // Step 1: Detection — require both parts of at least one trigger pair
        let detected = triggers.contains { pair in
            text.contains(pair.0) && text.contains(pair.1)
        }
        guard detected else { return nil }

        // Step 2: MRN
        let mrn = firstMatch(#"Patient_?\s*(\d{6,10})"#, in: text)?[1]
            ?? firstMatch(#"Patient\s*No\.?\s*(\d{6,10})"#, in: text)?[1]

        // Step 3: Patient name — "Surname, Firstname" before "Date of birth"
        var fullName: String?
        var dobFromName: String?

        // Pattern 1: Name before "Date of birth" label
        if let m = firstMatch(
            #"([A-Z][a-z]+,\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\n\s*Date of birth"#,
            in: text, options: [.caseInsensitive]
        ) {
            fullName = flipName(m[1])
        }
        // Pattern 2: Name followed directly by a date
        if fullName == nil, let m = firstMatch(
            #"([A-Z][a-z]+,\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*\n\s*(\d{1,2}[./]\d{1,2}[./]\d{4})"#,
            in: text, options: [.caseInsensitive]
        ) {
            fullName = flipName(m[1])
            dobFromName = m[2].replacingOccurrences(of: ".", with: "/")
        }

        // Step 4: Date of birth
        var dob = dobFromName
        if dob == nil {
            let dobPatterns = [
                #"Date of birth\s*\n?\s*(\d{1,2}[./]\d{1,2}[./]\d{4})"#,
                #"Date of birth\s+(\d{1,2}[./]\d{1,2}[./]\d{4})"#,
                #"\b(\d{1,2}[./]\d{1,2}[./]19\d{2})\b"#,
            ]
            for pattern in dobPatterns {
                if let m = firstMatch(pattern, in: text, options: [.caseInsensitive]) {
                    dob = m[1].replacingOccurrences(of: ".", with: "/")
                    break
                }
            }
        }

        // Step 5: Postcode — UK format on uppercased text, take first valid match
        let postcode = firstPostcode(in: text)

        // Step 6: Phones — only patient phones (before "Next of kin" / "Emergency contact")
        var phoneMobile: String?
        var phoneHome: String?
        let patientText: String = {
            for marker in ["Next of kin", "Emergency contact", "Telephone no. day"] {
                if let r = text.range(of: marker) {
                    return String(text[text.startIndex..<r.lowerBound])
                }
            }
            return text
        }()

        let phoneMatches = allMatches(#"(\d{5}\s*\d{6}|\d{11})"#, in: patientText)
        for groups in phoneMatches {
            let digits = groups[1].replacingOccurrences(of: " ", with: "")
            guard digits.count == 11 else { continue }
            if digits.hasPrefix("07"), phoneMobile == nil {
                phoneMobile = digits
            } else if phoneHome == nil {
                phoneHome = digits
            }
            if phoneMobile != nil, phoneHome != nil { break }
        }

        // Step 7: GP name — capture full name after Doctor/Dr/Dostor (same line only)
        var gpName: String?
        if let m = firstMatch(
            #"(?:Doctor|Dr|Dostor)\s+([A-Z][\w]*(?:[^\S\n]+[A-Z][\w]*)*)"#,
            in: text
        ) {
            let raw = m[1].trimmingCharacters(in: .whitespaces)
            gpName = "Dr \(raw)"
        }

        // Step 8: GP practice — text between "Doctor..." line and "Account"/"Reason"
        // Deliberately does NOT use "Medical" as a boundary (fixes known Python bug)
        var gpPractice: String?
        if let m = firstMatch(
            #"GP\s*\n.*?Address.*?\n(.*?)(?:Account|Reason)"#,
            in: text, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) {
            let lines = m[1]
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Find practice name: first non-empty line after the "Doctor..." line
            var afterDoctor = false
            for line in lines {
                let lower = line.lowercased()
                if lower.hasPrefix("doctor") || lower.hasPrefix("dr ") || lower.hasPrefix("dostor") {
                    afterDoctor = true
                    continue
                }
                if afterDoctor {
                    let skip = ["specialist", "date", "symptoms", "consulted", "reason", "age", "tel"]
                    if !skip.contains(where: { lower.contains($0) }) {
                        gpPractice = line
                        break
                    }
                }
            }
        }

        // Step 9: Validation — require both full_name and postcode
        guard fullName != nil, postcode != nil else { return nil }

        // Step 10: Assemble result
        let phones: PhoneInfo? = (phoneMobile != nil || phoneHome != nil)
            ? PhoneInfo(home: phoneHome, mobile: phoneMobile)
            : nil

        return AddressPageEntry(
            pageNumber: input.pageNumber,
            patient: PatientInfo(
                fullName: fullName,
                dateOfBirth: dob,
                phones: phones,
                mrn: mrn
            ),
            address: AddressInfo(postcode: postcode),
            gp: GPInfo(name: gpName, practice: gpPractice),
            extraction: ExtractionInfo(method: "clearwater_form", confidence: 0.9),
            addressType: "patient"
        )
    }

    // MARK: - Helpers

    /// Flip "Surname, Firstname" to "Firstname Surname"
    private func flipName(_ raw: String) -> String {
        let parts = raw.split(separator: ",", maxSplits: 1)
        guard parts.count == 2 else { return raw.trimmingCharacters(in: .whitespaces) }
        return "\(parts[1].trimmingCharacters(in: .whitespaces)) \(parts[0].trimmingCharacters(in: .whitespaces))"
    }

    /// First UK-format postcode found in text
    private func firstPostcode(in text: String) -> String? {
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

    /// Returns capture groups for the first match, or nil.
    /// Index 0 = full match, 1+ = capture groups.
    private func firstMatch(
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
    private func allMatches(
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
}
