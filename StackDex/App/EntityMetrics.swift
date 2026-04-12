import Foundation

extension CardStackEntity {
    var totalQuantity: Int {
        conditionBuckets.reduce(0) { $0 + max(0, $1.quantity) }
    }

    var valuationSummary: ValuationCalculator.Summary {
        let conditionQuantities = conditionBuckets.map {
            ValuationCalculator.ConditionQuantity(condition: $0.condition, quantity: $0.quantity)
        }
        let conditionPrices: [CardCondition: Decimal] = Dictionary(uniqueKeysWithValues: conditionBuckets.compactMap { bucket in
            guard let price = bucket.conditionPrice else {
                return nil
            }
            return (bucket.condition, price)
        })

        return ValuationCalculator.calculate(
            conditionQuantities: conditionQuantities,
            priceBook: .init(generalPrice: generalPrice, conditionPrices: conditionPrices)
        )
    }
}

extension CollectionEntity {
    var totalCardCount: Int {
        cardStacks.reduce(0) { $0 + $1.totalQuantity }
    }

    var totalEstimatedValue: Decimal {
        cardStacks.reduce(0) { $0 + $1.valuationSummary.totalValue }
    }

    var topCardImageURLString: String? {
        cardStacks
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first?
            .imageURLString
    }
}
