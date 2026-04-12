import Foundation
import Testing
@testable import StackDex

struct ValuationCalculatorTests {
    @Test func usesConditionPriceBeforeGeneralPrice() {
        let summary = ValuationCalculator.calculate(
            conditionQuantities: [
                .init(condition: .nearMint, quantity: 2),
            ],
            priceBook: .init(
                generalPrice: Decimal(string: "2.5"),
                conditionPrices: [.nearMint: Decimal(string: "3.0")!]
            )
        )

        #expect(summary.totalValue == Decimal(string: "6.0"))
        #expect(summary.includesApproximatePricing == false)
        #expect(summary.isIncomplete == false)
    }

    @Test func fallsBackToGeneralPriceAndMarksApproximate() {
        let summary = ValuationCalculator.calculate(
            conditionQuantities: [
                .init(condition: .lightlyPlayed, quantity: 3),
            ],
            priceBook: .init(generalPrice: Decimal(string: "1.25"))
        )

        #expect(summary.totalValue == Decimal(string: "3.75"))
        #expect(summary.includesApproximatePricing)
        #expect(summary.isIncomplete == false)
    }

    @Test func excludesUnknownPricesAndMarksIncompleteTotals() {
        let summary = ValuationCalculator.calculate(
            conditionQuantities: [
                .init(condition: .mint, quantity: 1),
                .init(condition: .damaged, quantity: 2),
            ],
            priceBook: .init(conditionPrices: [.mint: Decimal(string: "10")!])
        )

        #expect(summary.totalValue == Decimal(string: "10"))
        #expect(summary.valuedQuantity == 1)
        #expect(summary.unvaluedQuantity == 2)
        #expect(summary.isIncomplete)
    }
}
