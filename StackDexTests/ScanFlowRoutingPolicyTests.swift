import Foundation
import Testing
@testable import StackDex

struct ScanFlowRoutingPolicyTests {
    @Test func noMatchRoutesToManualSearchWithPrefill() {
        let outcome = ScanResultPolicy.Outcome(state: .noMatch, candidates: [])
        let hints = ScanLookupHints(normalizedQuery: "pikachu 199", nameTokens: ["pikachu"], possibleNumbers: ["199"])

        let nextStep = ScanFlowRoutingPolicy.nextStep(outcome: outcome, hints: hints)

        #expect(nextStep == .manualSearch(prefilledQuery: "pikachu 199"))
    }

    @Test func strongOrUncertainKeepCandidateFlow() {
        let candidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu"),
            confidence: 0.9
        )
        let hints = ScanLookupHints(normalizedQuery: "pikachu", nameTokens: ["pikachu"], possibleNumbers: [])

        let strong = ScanFlowRoutingPolicy.nextStep(
            outcome: .init(state: .strong, candidates: [candidate]),
            hints: hints
        )
        let uncertain = ScanFlowRoutingPolicy.nextStep(
            outcome: .init(state: .uncertain, candidates: [candidate]),
            hints: hints
        )

        #expect(strong == .showCandidates)
        #expect(uncertain == .showCandidates)
    }
}
