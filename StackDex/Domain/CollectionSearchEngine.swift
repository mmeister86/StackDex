import Foundation

enum CollectionSearchEngine {
    struct Record: Equatable {
        let stackID: UUID
        let cardName: String
        let setName: String?
        let cardNumber: String?
        let updatedAt: Date
    }

    static func filterAndSort(records: [Record], query: String) -> [Record] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let filtered = records.filter { record in
            guard !normalizedQuery.isEmpty else {
                return true
            }

            let candidates = [record.cardName, record.setName ?? "", record.cardNumber ?? ""]
            return candidates
                .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
                .contains(where: { $0.contains(normalizedQuery) })
        }

        return filtered.sorted(by: { $0.updatedAt > $1.updatedAt })
    }
}
