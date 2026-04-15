import CoreGraphics
import Foundation

enum ScanOCRRegion: String, Equatable {
    case nameBand
    case numberBand
    case fullCardFallback
}

struct RecognizedCardField: Equatable {
    let text: String
    let confidence: Float
    let region: ScanOCRRegion
    let boundingBox: CGRect
}

struct ScanQueryBuilder {
    func buildHints(from fields: [RecognizedCardField]) -> ScanLookupHints {
        let cleanedFields = fields
            .map { RecognizedCardField(text: normalizeWhitespace($0.text), confidence: $0.confidence, region: $0.region, boundingBox: $0.boundingBox) }
            .filter { !$0.text.isEmpty }

        let preferredName = cleanedFields
            .filter { $0.region == ScanOCRRegion.nameBand && containsLetters($0.text) }
            .sorted(by: fieldPriority)
            .first

        let possibleNumbers = numberCandidates(from: cleanedFields)
        let hasStructuredNumber = cleanedFields.contains { $0.region == .numberBand && tokenizeNumberCandidates($0.text).isEmpty == false }
        let structuredQuery = [preferredName?.text, possibleNumbers.first]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if preferredName != nil || hasStructuredNumber {
            return ScanLookupHints(
                normalizedQuery: structuredQuery,
                nameTokens: tokenize(preferredName?.text ?? structuredQuery),
                possibleNumbers: possibleNumbers
            )
        }

        let fallbackTokens = rankedFallbackTokens(from: cleanedFields)
        return ScanLookupHints(
            normalizedQuery: fallbackTokens.joined(separator: " "),
            nameTokens: fallbackTokens,
            possibleNumbers: fallbackTokens.filter(isNumberLike)
        )
    }

    private func numberCandidates(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var numbers: [String] = []

        let ranked = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .numberBand || isNumberLike($0.text) }

        for field in ranked {
            for token in tokenizeNumberCandidates(field.text) {
                guard seen.insert(token).inserted else { continue }
                numbers.append(token)
            }
        }

        return Array(numbers.prefix(4))
    }

    private func rankedFallbackTokens(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var tokens: [String] = []

        for field in fields.sorted(by: fieldPriority) {
            for token in tokenize(field.text) {
                let key = token.lowercased()
                guard seen.insert(key).inserted else { continue }
                tokens.append(token)
                if tokens.count == 8 {
                    return tokens
                }
            }
        }

        return tokens
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/-")).inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }

    private func tokenizeNumberCandidates(_ text: String) -> [String] {
        tokenize(text)
            .map(normalizeNumericOCR)
            .filter(isNumberLike)
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeNumericOCR(_ text: String) -> String {
        let mapping: [Character: Character] = [
            "O": "0", "o": "0",
            "I": "1", "l": "1", "|": "1",
            "S": "5",
        ]

        return String(text.map { character in
            mapping[character] ?? character
        })
    }

    private func isNumberLike(_ text: String) -> Bool {
        let normalized = normalizeNumericOCR(text)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/-"))
        guard normalized.unicodeScalars.allSatisfy(allowed.contains(_:)) else {
            return false
        }
        return normalized.contains(where: \.isNumber)
    }

    private func containsLetters(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: CharacterSet.letters.contains(_:))
    }

    private func fieldPriority(_ lhs: RecognizedCardField, _ rhs: RecognizedCardField) -> Bool {
        let rank: [ScanOCRRegion: Int] = [.nameBand: 3, .numberBand: 2, .fullCardFallback: 1]
        let lhsRank = rank[lhs.region, default: 0]
        let rhsRank = rank[rhs.region, default: 0]
        if lhsRank != rhsRank {
            return lhsRank > rhsRank
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.text.count > rhs.text.count
    }
}
