import Foundation
import Testing
@testable import StackDex

struct ScanResultPolicyTests {
    @Test func evaluateTrimsToMaximumThreeCandidates() {
        let candidates = [
            candidate(id: "a", confidence: 0.9),
            candidate(id: "b", confidence: 0.8),
            candidate(id: "c", confidence: 0.7),
            candidate(id: "d", confidence: 0.6),
        ]

        let outcome = ScanResultPolicy.evaluate(candidates: candidates, maxCandidates: 3)

        #expect(outcome.candidates.count == 3)
        #expect(outcome.candidates.map(\.id) == ["a", "b", "c"])
    }

    @Test func evaluateMarksLowConfidenceAsUncertain() {
        let outcome = ScanResultPolicy.evaluate(candidates: [candidate(id: "x", confidence: 0.62)], maxCandidates: 3)

        #expect(outcome.state == .uncertain)
    }

    @Test func evaluateMarksEmptyAsNoMatch() {
        let outcome = ScanResultPolicy.evaluate(candidates: [], maxCandidates: 3)

        #expect(outcome.state == .noMatch)
        #expect(outcome.candidates.isEmpty)
    }

    private func candidate(id: String, confidence: Double) -> CardLookupCandidate {
        CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: id, name: id.uppercased()),
            confidence: confidence
        )
    }
}
