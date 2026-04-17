import Foundation
import Testing
@testable import StackDex

@MainActor
struct ScanCandidateValidationPolicyTests {
    @Test func filtersCandidatesToExactCollectorNumberWhenNameSignalIsWeak() {
        let weakNameHints = ScanLookupHints(
            normalizedQuery: "Lor 081/088",
            nameTokens: ["Lor"],
            possibleNumbers: ["081/088"],
            possibleSetCodes: ["ZUGES"],
            signalQuality: ScanSignalQuality(
                isWeakNameSignal: true,
                hasCollectorNumberSignal: true
            ),
        )

        let candidates = [
            CardLookupCandidate(
                identity: CardIdentity(canonicalCardID: "wrong", name: "Card A", cardNumber: "001"),
                imageURLString: nil,
                confidence: 0.82
            ),
            CardLookupCandidate(
                identity: CardIdentity(canonicalCardID: "right", name: "Card B", cardNumber: "81"),
                imageURLString: nil,
                confidence: 0.77
            ),
        ]

        let result = ScanCandidateValidationPolicy.validate(candidates: candidates, hints: weakNameHints)

        #expect(result.numberGuardApplied)
        #expect(result.numberGuardFilteredCount == 1)
        #expect(result.comparedNumber == "81")
        #expect(result.candidates.map(\.identity.canonicalCardID) == ["right"])
    }

    @Test func preservesCandidatesWithoutGuardForStrongSignals() {
        let strongNameHints = ScanLookupHints(
            normalizedQuery: "Pikachu",
            nameTokens: ["Pikachu"],
            possibleNumbers: ["199/091"],
            possibleSetCodes: ["SVI"],
            signalQuality: ScanSignalQuality(
                isWeakNameSignal: false,
                hasCollectorNumberSignal: true
            ),
        )

        let candidates = [
            CardLookupCandidate(
                identity: CardIdentity(canonicalCardID: "wrong", name: "Card A", cardNumber: "001"),
                imageURLString: nil,
                confidence: 0.82
            ),
        ]

        let result = ScanCandidateValidationPolicy.validate(candidates: candidates, hints: strongNameHints)

        #expect(!result.numberGuardApplied)
        #expect(result.candidates.count == 1)
    }
}
