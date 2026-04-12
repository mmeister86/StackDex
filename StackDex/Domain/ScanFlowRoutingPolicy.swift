import Foundation

enum ScanFlowRoutingPolicy {
    enum NextStep: Equatable {
        case showCandidates
        case manualSearch(prefilledQuery: String)
    }

    static func nextStep(outcome: ScanResultPolicy.Outcome, hints: ScanLookupHints) -> NextStep {
        switch outcome.state {
        case .noMatch:
            return .manualSearch(prefilledQuery: hints.normalizedQuery)
        case .strong, .uncertain:
            return .showCandidates
        }
    }
}
