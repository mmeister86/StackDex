import Foundation

enum ScanResultPolicy {
    enum MatchState: Equatable {
        case strong
        case uncertain
        case noMatch
    }

    struct Outcome: Equatable {
        let state: MatchState
        let candidates: [CardLookupCandidate]
    }

    static func evaluate(candidates: [CardLookupCandidate], maxCandidates: Int = 3) -> Outcome {
        let limited = Array(candidates.prefix(max(1, maxCandidates)))
        guard let first = limited.first else {
            return Outcome(state: .noMatch, candidates: [])
        }

        if first.confidence >= 0.75 {
            return Outcome(state: .strong, candidates: limited)
        }

        return Outcome(state: .uncertain, candidates: limited)
    }
}
