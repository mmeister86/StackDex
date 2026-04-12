import Foundation

struct CardLookupRequest {
    let recognizedTexts: [String]
    let hints: ScanLookupHints?
    let maxResults: Int

    init(recognizedTexts: [String], hints: ScanLookupHints? = nil, maxResults: Int = 3) {
        self.recognizedTexts = recognizedTexts
        self.hints = hints
        self.maxResults = max(1, maxResults)
    }
}

protocol CardLookupServing {
    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate]
}

extension CardLookupServing {
    func lookupCandidates(from recognizedTexts: [String], maxResults: Int) async -> [CardLookupCandidate] {
        await lookupCandidates(for: CardLookupRequest(recognizedTexts: recognizedTexts, maxResults: maxResults))
    }
}

struct CardLookupCandidate: Identifiable, Hashable, Sendable {
    let id: String
    let identity: CardIdentity
    let imageURLString: String?
    let generalPrice: Decimal?
    let confidence: Double

    init(
        identity: CardIdentity,
        imageURLString: String? = nil,
        generalPrice: Decimal? = nil,
        confidence: Double
    ) {
        self.id = identity.canonicalCardID
        self.identity = identity
        self.imageURLString = imageURLString
        self.generalPrice = generalPrice
        self.confidence = confidence
    }
}

struct MockCardLookupService: CardLookupServing {
    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate] {
        let recognizedSource = request.recognizedTexts.joined(separator: " ").lowercased()
        let hintedSource = request.hints?.normalizedQuery.lowercased() ?? ""
        let source = [recognizedSource, hintedSource]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let allCandidates: [CardLookupCandidate] = [
            .init(
                identity: CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu", setName: "Paldea Evolved", cardNumber: "199"),
                generalPrice: Decimal(string: "14.5"),
                confidence: source.contains("pikachu") ? 0.91 : 0.64
            ),
            .init(
                identity: CardIdentity(canonicalCardID: "sv3-151", name: "Charizard ex", setName: "151", cardNumber: "006"),
                generalPrice: Decimal(string: "38"),
                confidence: source.contains("char") ? 0.87 : 0.53
            ),
            .init(
                identity: CardIdentity(canonicalCardID: "swsh1-032", name: "Sobble", setName: "Sword & Shield", cardNumber: "032"),
                generalPrice: Decimal(string: "1.2"),
                confidence: source.contains("sobble") ? 0.84 : 0.42
            ),
        ]

        let sorted = allCandidates.sorted(by: { $0.confidence > $1.confidence })
        let positiveMatches = sorted.filter { candidate in
            source.contains(candidate.identity.name.lowercased().split(separator: " ").first ?? "") || candidate.confidence >= 0.6
        }
        return Array(positiveMatches.prefix(request.maxResults))
    }
}
