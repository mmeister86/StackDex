import CoreGraphics
import Foundation
import Testing
@testable import StackDex

@MainActor struct ScanQueryBuilderTests {
    private let builder = ScanQueryBuilder()

    @Test func buildsStructuredQueryWithSetCodeForModernCards() {
        let hints = builder.buildHints(from: [
            .init(text: "Pikachu ex", confidence: 0.98, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.7, height: 0.1)),
            .init(text: "SVI DE 199/091", confidence: 0.9, region: .collectorFooter, boundingBox: CGRect(x: 0.08, y: 0.84, width: 0.4, height: 0.08)),
            .init(text: "Illustration Rare", confidence: 0.85, region: .collectorFooter, boundingBox: CGRect(x: 0.62, y: 0.84, width: 0.26, height: 0.08)),
            .init(text: "Thunderbolt charge attack", confidence: 0.94, region: .attackBox, boundingBox: CGRect(x: 0.1, y: 0.25, width: 0.8, height: 0.35)),
        ])

        #expect(hints.normalizedQuery == "Pikachu ex 199/091 SVI")
        #expect(hints.nameTokens == ["Pikachu", "ex"])
        #expect(hints.possibleNumbers == ["199/091"])
        #expect(hints.possibleSetCodes == ["SVI"])
        #expect(hints.possibleRarities.contains("Illustration Rare"))
        #expect(hints.possibleLanguages == ["DE"])
    }

    @Test func oldLayoutWithoutSetCodeFallsBackToNameAndNumber() {
        let hints = builder.buildHints(from: [
            .init(text: "Charizard", confidence: 0.98, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.7, height: 0.1)),
            .init(text: "4/102", confidence: 0.88, region: .collectorFooter, boundingBox: CGRect(x: 0.08, y: 0.84, width: 0.3, height: 0.07)),
            .init(text: "D", confidence: 0.9, region: .collectorFooter, boundingBox: CGRect(x: 0.4, y: 0.84, width: 0.05, height: 0.07)),
        ])

        #expect(hints.normalizedQuery == "Charizard 4/102")
        #expect(hints.possibleSetCodes.isEmpty)
    }

    @Test func normalizesCommonOCRConfusionsInNumericContexts() {
        let hints = builder.buildHints(from: [
            .init(text: "I99/O9B", confidence: 0.84, region: .collectorFooter, boundingBox: CGRect(x: 0.7, y: 0.88, width: 0.18, height: 0.05)),
        ])

        #expect(hints.possibleNumbers == ["199/098"])
        #expect(hints.normalizedQuery == "199/098")
    }

    @Test func ruleMarkSingleLetterIsNotMisclassifiedAsSetCode() {
        let hints = builder.buildHints(from: [
            .init(text: "Zwirrlicht", confidence: 0.91, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.4, height: 0.1)),
            .init(text: "D 069/185", confidence: 0.79, region: .collectorFooter, boundingBox: CGRect(x: 0.1, y: 0.84, width: 0.38, height: 0.08)),
        ])

        #expect(hints.possibleSetCodes.isEmpty)
        #expect(hints.possibleNumbers.contains("069/185"))
    }

    @Test func noisyBodyTextDoesNotDominateStructuredQuery() {
        let hints = builder.buildHints(from: [
            .init(text: "Pikachu ex", confidence: 0.96, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.7, height: 0.1)),
            .init(text: "Thunderbolt spark charge attack retreat ability", confidence: 0.91, region: .attackBox, boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.3)),
            .init(text: "199/091", confidence: 0.89, region: .collectorFooter, boundingBox: CGRect(x: 0.68, y: 0.88, width: 0.2, height: 0.06)),
        ])

        #expect(hints.normalizedQuery.lowercased().contains("pikachu ex"))
        #expect(hints.normalizedQuery.contains("199/091"))
        #expect(!hints.normalizedQuery.lowercased().contains("thunderbolt"))
    }

    @Test func uiOverlayTextIsRejectedAndFallsBackToCollectorNumber() {
        let hints = builder.buildHints(from: [
            .init(text: "Gespeicherte Elemente", confidence: 1, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.02, width: 0.45, height: 0.06)),
            .init(text: "Gate to the Games", confidence: 1, region: .titleStrip, boundingBox: CGRect(x: 0.5, y: 0.02, width: 0.4, height: 0.06)),
            .init(text: "UND 131/195", confidence: 0.91, region: .collectorFooter, boundingBox: CGRect(x: 0.09, y: 0.84, width: 0.38, height: 0.08)),
        ])

        #expect(hints.nameTokens.isEmpty)
        #expect(hints.possibleSetCodes.isEmpty)
        #expect(hints.normalizedQuery == "131/195")
    }

    @Test func weakMixedAlphaNumericNoiseDoesNotProduceQuery() {
        let hints = builder.buildHints(from: [
            .init(text: "24SE2", confidence: 0.5, region: .titleStrip, boundingBox: CGRect(x: 0.16, y: 0.06, width: 0.22, height: 0.08)),
            .init(text: "230", confidence: 0.76, region: .attackBox, boundingBox: CGRect(x: 0.73, y: 0.52, width: 0.12, height: 0.05)),
            .init(text: "nimmt jener Spieler", confidence: 0.72, region: .attackBox, boundingBox: CGRect(x: 0.2, y: 0.58, width: 0.45, height: 0.09)),
        ])

        #expect(hints.nameTokens.isEmpty)
        #expect(!hints.hasCollectorNumberSignal)
        #expect(hints.normalizedQuery.isEmpty)
    }

    @Test func evolutionSentenceInNameBandIsIgnoredInFavorOfCardName() {
        let hints = builder.buildHints(from: [
            .init(text: "Entwickelt sich aus Alpollo", confidence: 0.99, region: .evolutionLine, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.08)),
            .init(text: "Mega-Gengar ex", confidence: 0.85, region: .titleStrip, boundingBox: CGRect(x: 0.1, y: 0.03, width: 0.7, height: 0.08)),
            .init(text: "056/094", confidence: 0.9, region: .collectorFooter, boundingBox: CGRect(x: 0.68, y: 0.88, width: 0.2, height: 0.06)),
        ])

        #expect(hints.normalizedQuery == "Mega-Gengar ex 056/094")
        #expect(!hints.normalizedQuery.lowercased().contains("entwickelt sich aus"))
        #expect(hints.nameTokens == ["Mega-Gengar", "ex"])
    }

    @Test func attackLineWithDamageValueIsNotUsedAsCardName() {
        let hints = builder.buildHints(from: [
            .init(text: "Sturm der Leere 230", confidence: 0.92, region: .titleStrip, boundingBox: CGRect(x: 0.18, y: 0.3, width: 0.64, height: 0.09)),
        ])

        #expect(hints.nameTokens.isEmpty)
        #expect(hints.normalizedQuery.isEmpty)
    }
}
