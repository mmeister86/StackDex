import CoreGraphics
import Foundation
import Testing
@testable import StackDex

@MainActor struct ScanQueryBuilderTests {
    private let builder = ScanQueryBuilder()

    @Test func prefersNameBandAndNumberBandForNormalizedQuery() {
        let hints = builder.buildHints(from: [
            .init(text: "Pikachu ex", confidence: 0.98, region: .nameBand, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.7, height: 0.1)),
            .init(text: "199/091", confidence: 0.92, region: .numberBand, boundingBox: CGRect(x: 0.73, y: 0.88, width: 0.16, height: 0.05)),
            .init(text: "Thunderbolt charge attack", confidence: 0.94, region: .fullCardFallback, boundingBox: CGRect(x: 0.1, y: 0.25, width: 0.8, height: 0.35)),
        ])

        #expect(hints.normalizedQuery == "Pikachu ex 199/091")
        #expect(hints.nameTokens == ["Pikachu", "ex"])
        #expect(hints.possibleNumbers == ["199/091"])
    }

    @Test func normalizesCommonOCRConfusionsInNumericContexts() {
        let hints = builder.buildHints(from: [
            .init(text: "I99/O9I", confidence: 0.84, region: .numberBand, boundingBox: CGRect(x: 0.7, y: 0.88, width: 0.18, height: 0.05)),
        ])

        #expect(hints.possibleNumbers == ["199/091"])
        #expect(hints.normalizedQuery == "199/091")
    }

    @Test func fallsBackToRankedTokensWhenStructuredFieldsAreWeak() {
        let hints = builder.buildHints(from: [
            .init(text: "flareon", confidence: 0.55, region: .fullCardFallback, boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.08)),
            .init(text: "rare holo 003", confidence: 0.52, region: .fullCardFallback, boundingBox: CGRect(x: 0.1, y: 0.35, width: 0.4, height: 0.08)),
        ])

        #expect(hints.normalizedQuery.contains("flareon"))
        #expect(hints.normalizedQuery.contains("rare"))
        #expect(hints.normalizedQuery.contains("003"))
        #expect(hints.nameTokens.contains("flareon"))
        #expect(hints.nameTokens.contains("003"))
        #expect(!hints.normalizedQuery.isEmpty)
    }
}
