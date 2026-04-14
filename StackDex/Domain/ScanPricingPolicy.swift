import Foundation

enum ScanPricingPolicy {
    struct Resolution: Equatable {
        let conditionPrice: Decimal?
        let isApproximatePrice: Bool
    }

    static func resolve(
        candidate: CardLookupCandidate,
        selectedCondition: CardCondition?
    ) -> Resolution {
        let resolvedCondition = selectedCondition ?? .nearMint

        if let exactPrice = candidate.conditionPrices[resolvedCondition] {
            return Resolution(conditionPrice: exactPrice, isApproximatePrice: false)
        }

        if let generalPrice = candidate.generalPrice {
            return Resolution(conditionPrice: generalPrice, isApproximatePrice: true)
        }

        return Resolution(conditionPrice: nil, isApproximatePrice: selectedCondition == nil)
    }

    static func merge(existing: Resolution?, incoming: Resolution) -> Resolution {
        guard let existing else {
            return incoming
        }

        guard existing.conditionPrice != nil else {
            return incoming
        }

        guard incoming.conditionPrice != nil else {
            return existing
        }

        if existing.isApproximatePrice == false && incoming.isApproximatePrice == true {
            return existing
        }

        if existing.isApproximatePrice == true && incoming.isApproximatePrice == false {
            return incoming
        }

        return incoming
    }
}
