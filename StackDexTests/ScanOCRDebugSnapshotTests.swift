import CoreGraphics
import Foundation
import Testing
@testable import StackDex

struct ScanOCRDebugSnapshotTests {
    @Test func topCandidateTextIsJoinedLineByLine() {
        let snapshot = ScanOCRDebugSnapshot(
            updatedAt: .now,
            source: .captured,
            rawObservations: [
                .init(
                    region: .titleStrip,
                    boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.2),
                    candidates: [
                        .init(text: "Pikachu ex", confidence: 0.92),
                        .init(text: "Pikachu cx", confidence: 0.61),
                    ]
                ),
                .init(
                    region: .collectorFooter,
                    boundingBox: CGRect(x: 0.4, y: 0.7, width: 0.3, height: 0.1),
                    candidates: [
                        .init(text: "199/091", confidence: 0.88),
                    ]
                ),
            ]
        )

        #expect(snapshot.topCandidateLines == ["Pikachu ex", "199/091"])
        #expect(snapshot.fullRecognizedText == "Pikachu ex\n199/091")
    }

    @Test func confidenceFormattingIsStable() {
        #expect(ScanOCRDebugFormatting.confidenceString(0.951) == "95.1%")
        #expect(ScanOCRDebugFormatting.confidenceString(1.0) == "100.0%")
        #expect(ScanOCRDebugFormatting.confidenceString(0.0) == "0.0%")
    }

    @Test func emptySnapshotUsesConfiguredEmptyStateMessage() {
        let emptySnapshot = ScanOCRDebugSnapshot(
            updatedAt: .now,
            source: .imported,
            rawObservations: []
        )

        #expect(emptySnapshot.topCandidateLines.isEmpty)
        #expect(emptySnapshot.fullRecognizedText.isEmpty)
        #expect(ScanOCRDebugTabView.emptyStateMessage == "Fuehre einen Kamera- oder Foto-Scan aus, um Rohtexte zu sehen.")
    }
}
