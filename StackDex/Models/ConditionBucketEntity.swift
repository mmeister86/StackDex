import Foundation
import SwiftData

@Model
final class ConditionBucketEntity {
    var id: UUID
    var conditionRawValue: String
    var quantity: Int
    var conditionPrice: Decimal?
    var isApproximatePrice: Bool

    var cardStack: CardStackEntity?

    init(
        id: UUID = UUID(),
        condition: CardCondition,
        quantity: Int,
        conditionPrice: Decimal? = nil,
        isApproximatePrice: Bool = false,
        cardStack: CardStackEntity? = nil
    ) {
        self.id = id
        self.conditionRawValue = condition.rawValue
        self.quantity = max(0, quantity)
        self.conditionPrice = conditionPrice
        self.isApproximatePrice = isApproximatePrice
        self.cardStack = cardStack
    }

    var condition: CardCondition {
        get { CardCondition(rawValue: conditionRawValue) ?? .nearMint }
        set { conditionRawValue = newValue.rawValue }
    }
}
