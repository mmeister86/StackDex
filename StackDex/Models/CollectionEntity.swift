import Foundation
import SwiftData

@Model
final class CollectionEntity {
    var id: UUID
    var name: String
    var collectionDescription: String?
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CardStackEntity.collection)
    var cardStacks: [CardStackEntity]

    init(
        id: UUID = UUID(),
        name: String,
        collectionDescription: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastUsedAt: Date = .now,
        cardStacks: [CardStackEntity] = []
    ) {
        self.id = id
        self.name = name
        self.collectionDescription = collectionDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.cardStacks = cardStacks
    }
}
