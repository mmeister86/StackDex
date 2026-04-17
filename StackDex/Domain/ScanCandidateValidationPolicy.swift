import Foundation

enum ScanCandidateValidationPolicy {
    struct Result: Equatable {
        let candidates: [CardLookupCandidate]
        let numberGuardApplied: Bool
        let numberGuardFilteredCount: Int
        let comparedNumber: String?

        static let empty = Result(
            candidates: [],
            numberGuardApplied: false,
            numberGuardFilteredCount: 0,
            comparedNumber: nil
        )
    }

    static func validate(
        candidates: [CardLookupCandidate],
        hints: ScanLookupHints
    ) -> Result {
        guard
            hints.signalQuality.isWeakNameSignal,
            hints.signalQuality.hasCollectorNumberSignal,
            let targetNumber = normalizedTargetNumber(from: hints.possibleNumbers)
        else {
            return Result(
                candidates: candidates,
                numberGuardApplied: false,
                numberGuardFilteredCount: 0,
                comparedNumber: nil
            )
        }

        let filtered = candidates.filter { candidate in
            normalizedCandidateNumber(candidate.identity.cardNumber) == targetNumber
        }

        return Result(
            candidates: filtered,
            numberGuardApplied: true,
            numberGuardFilteredCount: max(candidates.count - filtered.count, 0),
            comparedNumber: targetNumber
        )
    }

    private static func normalizedTargetNumber(from possibleNumbers: [String]) -> String? {
        let number = possibleNumbers.first(where: { $0.contains("/") })
        guard let number else { return nil }
        return normalizedCollectorNumberPart(number)
    }

    static func normalizedCollectorNumberPart(_ raw: String) -> String {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .split(separator: "/")
            .first?
            .description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let stripped = normalized.replacingOccurrences(of: "^0+(?=\\d)", with: "", options: .regularExpression)
        return stripped
    }

    private static func normalizedCandidateNumber(_ raw: String?) -> String? {
        guard let raw else {
            return nil
        }

        return normalizedCollectorNumberPart(raw).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
