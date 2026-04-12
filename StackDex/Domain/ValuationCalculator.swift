import Foundation

enum ValuationCalculator {
    struct ConditionQuantity: Equatable, Sendable {
        let condition: CardCondition
        let quantity: Int

        init(condition: CardCondition, quantity: Int) {
            self.condition = condition
            self.quantity = max(0, quantity)
        }
    }

    struct PriceBook: Equatable, Sendable {
        let generalPrice: Decimal?
        let conditionPrices: [CardCondition: Decimal]

        init(generalPrice: Decimal? = nil, conditionPrices: [CardCondition: Decimal] = [:]) {
            self.generalPrice = generalPrice
            self.conditionPrices = conditionPrices
        }
    }

    struct Summary: Equatable, Sendable {
        let totalValue: Decimal
        let isIncomplete: Bool
        let includesApproximatePricing: Bool
        let valuedQuantity: Int
        let unvaluedQuantity: Int
    }

    static func calculate(
        conditionQuantities: [ConditionQuantity],
        priceBook: PriceBook
    ) -> Summary {
        var total: Decimal = 0
        var usedApproximatePrice = false
        var valuedQuantity = 0
        var unvaluedQuantity = 0

        for bucket in conditionQuantities where bucket.quantity > 0 {
            if let exact = priceBook.conditionPrices[bucket.condition] {
                total += exact * bucket.quantity
                valuedQuantity += bucket.quantity
                continue
            }

            if let general = priceBook.generalPrice {
                total += general * bucket.quantity
                valuedQuantity += bucket.quantity
                usedApproximatePrice = true
                continue
            }

            unvaluedQuantity += bucket.quantity
        }

        return Summary(
            totalValue: total,
            isIncomplete: unvaluedQuantity > 0,
            includesApproximatePricing: usedApproximatePrice,
            valuedQuantity: valuedQuantity,
            unvaluedQuantity: unvaluedQuantity
        )
    }
}

private extension Decimal {
    static func * (lhs: Decimal, rhs: Int) -> Decimal {
        lhs * Decimal(rhs)
    }
}
