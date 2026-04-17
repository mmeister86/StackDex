import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

protocol OCRTextRefining {
    func refine(evidence: OCRRefinementEvidence) async throws -> OCRRefinementSelection?
}

struct OCRRefinementEvidence: Sendable, Equatable {
    let currentBestNameCandidateID: String?
    let currentBestCollectorNumberCandidateID: String?
    let nameCandidates: [OCRRefinementCandidate]
    let collectorNumberCandidates: [OCRRefinementCandidate]

    var hasUsefulCandidates: Bool {
        !nameCandidates.isEmpty || !collectorNumberCandidates.isEmpty
    }
}

struct OCRRefinementCandidate: Sendable, Equatable {
    let id: String
    let text: String
    let region: String
    let confidence: Float
}

struct OCRRefinementSelection: Sendable, Equatable {
    let selectedNameCandidateID: String?
    let selectedCollectorNumberCandidateID: String?
}

struct SystemFoundationModelOCRTextRefiner: OCRTextRefining {
    func refine(evidence: OCRRefinementEvidence) async throws -> OCRRefinementSelection? {
        guard evidence.hasUsefulCandidates else {
            return nil
        }

        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else {
            return nil
        }

        let session = LanguageModelSession(instructions: """
        You improve OCR evidence for a Pokemon card.
        Choose only from the provided candidate IDs.
        Never invent a card name.
        Never invent a collector number.
        Prefer titleStrip or evolutionLine candidates for the card name.
        Prefer collectorFooter candidates for the collector number.
        If no candidate is clearly better, keep the current best candidate ID.
        """)

        let response = try await session.respond(
            to: prompt(for: evidence),
            generating: OCRRefinementDecision.self
        )

        return OCRRefinementSelection(
            selectedNameCandidateID: response.content.selectedNameCandidateID.nilIfEmpty,
            selectedCollectorNumberCandidateID: response.content.selectedCollectorNumberCandidateID.nilIfEmpty
        )
        #else
        return nil
        #endif
    }

    private func prompt(for evidence: OCRRefinementEvidence) -> String {
        let nameCandidates = renderedCandidates(evidence.nameCandidates)
        let collectorCandidates = renderedCandidates(evidence.collectorNumberCandidates)
        let currentName = evidence.currentBestNameCandidateID ?? ""
        let currentNumber = evidence.currentBestCollectorNumberCandidateID ?? ""

        return """
        Current best name candidate ID: \(currentName)
        Current best collector number candidate ID: \(currentNumber)

        Name candidates:
        \(nameCandidates)

        Collector number candidates:
        \(collectorCandidates)

        Return only candidate IDs from these lists. If the current best is already correct, return it unchanged.
        """
    }

    private func renderedCandidates(_ candidates: [OCRRefinementCandidate]) -> String {
        guard !candidates.isEmpty else {
            return "<none>"
        }

        return candidates.map { candidate in
            let confidence = String(format: "%.3f", Double(candidate.confidence))
            return "- id=\(candidate.id) | text=\(candidate.text) | region=\(candidate.region) | confidence=\(confidence)"
        }.joined(separator: "\n")
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
private struct OCRRefinementDecision {
    let selectedNameCandidateID: String
    let selectedCollectorNumberCandidateID: String
}
#endif

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
