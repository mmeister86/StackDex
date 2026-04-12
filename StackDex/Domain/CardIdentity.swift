import Foundation

struct CardIdentity: Hashable, Codable, Sendable {
    let canonicalCardID: String
    let name: String
    let setName: String?
    let cardNumber: String?

    init(canonicalCardID: String, name: String, setName: String? = nil, cardNumber: String? = nil) {
        self.canonicalCardID = canonicalCardID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.setName = setName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cardNumber = cardNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
