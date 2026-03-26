import Foundation

extension String {
    /// Title-case ALL CAPS words longer than 2 characters.
    /// Preserves: postcodes (RH6 7DG), abbreviations (GP, NHS, MRN, ODS),
    /// mixed-case words (McDonald), and already-correct words.
    var displayTitleCased: String {
        let preserve: Set<String> = ["NHS", "GP", "MRN", "ODS", "UK", "PCT", "CCG", "ICB", "IRC"]

        return self.split(separator: " ").map { word in
            let w = String(word)
            if preserve.contains(w) { return w }
            if w.count <= 2 { return w }
            if w.contains(where: { $0.isNumber }) { return w }
            // Only transform ALL CAPS words
            guard w == w.uppercased() && w.contains(where: { $0.isLetter }) else { return w }
            // Capitalise first letter, lowercase the rest, handle O' and Mc
            var result = w.prefix(1).uppercased() + w.dropFirst().lowercased()
            if result.hasPrefix("O'") && result.count > 2 {
                let i = result.index(result.startIndex, offsetBy: 2)
                result = "O'" + String(result[i]).uppercased() + result[result.index(after: i)...]
            }
            if result.hasPrefix("Mc") && result.count > 2 {
                let i = result.index(result.startIndex, offsetBy: 2)
                result = "Mc" + String(result[i]).uppercased() + result[result.index(after: i)...]
            }
            return result
        }.joined(separator: " ")
    }
}
