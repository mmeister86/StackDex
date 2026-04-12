import Foundation
import SwiftData

@Model
final class CardStackEntity {
    var id: UUID
    var canonicalCardID: String
    var cardName: String
    var setName: String?
    var cardNumber: String?
    var imageURLString: String?
    var generalPrice: Decimal?
    var createdAt: Date
    var updatedAt: Date

    var collection: CollectionEntity?

    @Relationship(deleteRule: .cascade, inverse: \ConditionBucketEntity.cardStack)
    var conditionBuckets: [ConditionBucketEntity]

    init(
        id: UUID = UUID(),
        canonicalCardID: String,
        cardName: String,
        setName: String? = nil,
        cardNumber: String? = nil,
        imageURLString: String? = nil,
        generalPrice: Decimal? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        collection: CollectionEntity? = nil,
        conditionBuckets: [ConditionBucketEntity] = []
    ) {
        self.id = id
        self.canonicalCardID = canonicalCardID
        self.cardName = cardName
        self.setName = setName
        self.cardNumber = cardNumber
        self.imageURLString = imageURLString
        self.generalPrice = generalPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.collection = collection
        self.conditionBuckets = conditionBuckets
    }
}
