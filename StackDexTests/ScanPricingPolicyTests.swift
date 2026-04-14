import Foundation
import Testing
@testable import StackDex

struct ScanPricingPolicyTests {
    @Test func resolveUsesExactConditionPriceWhenAvailable() {
        let candidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "card-1", name: "Card 1"),
            generalPrice: Decimal(string: "3.50"),
            conditionPrices: [.lightlyPlayed: Decimal(string: "2.10")!],
            confidence: 0.9
        )

        let resolution = ScanPricingPolicy.resolve(candidate: candidate, selectedCondition: .lightlyPlayed)

        #expect(resolution.conditionPrice == Decimal(string: "2.10"))
        #expect(resolution.isApproximatePrice == false)
    }

    @Test func resolveFallsBackToGeneralPriceAsApproximate() {
        let candidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "card-2", name: "Card 2"),
            generalPrice: Decimal(string: "5.75"),
            conditionPrices: [:],
            confidence: 0.85
        )

        let resolution = ScanPricingPolicy.resolve(candidate: candidate, selectedCondition: .mint)

        #expect(resolution.conditionPrice == Decimal(string: "5.75"))
        #expect(resolution.isApproximatePrice == true)
    }

    @Test func resolveKeepsPriceNilAndPreservesApproximateWhenConditionIsOmitted() {
        let candidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "card-3", name: "Card 3"),
            generalPrice: nil,
            conditionPrices: [:],
            confidence: 0.8
        )

        let resolution = ScanPricingPolicy.resolve(candidate: candidate, selectedCondition: nil)

        #expect(resolution.conditionPrice == nil)
        #expect(resolution.isApproximatePrice == true)
    }

    @Test func mergeAcceptsIncomingWhenExistingPriceIsNil() {
        let existing = ScanPricingPolicy.Resolution(conditionPrice: nil, isApproximatePrice: false)
        let incoming = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "3.40"), isApproximatePrice: true)

        let merged = ScanPricingPolicy.merge(existing: existing, incoming: incoming)

        #expect(merged == incoming)
    }

    @Test func mergeKeepsExistingWhenExistingIsExactAndIncomingIsApproximate() {
        let existing = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "6.00"), isApproximatePrice: false)
        let incoming = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "5.00"), isApproximatePrice: true)

        let merged = ScanPricingPolicy.merge(existing: existing, incoming: incoming)

        #expect(merged == existing)
    }

    @Test func mergeReplacesExistingWhenExistingIsApproximateAndIncomingIsExact() {
        let existing = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "5.00"), isApproximatePrice: true)
        let incoming = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "6.00"), isApproximatePrice: false)

        let merged = ScanPricingPolicy.merge(existing: existing, incoming: incoming)

        #expect(merged == incoming)
    }

    @Test func mergeUsesLatestWhenPrecisionIsEqual() {
        let existing = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "7.00"), isApproximatePrice: true)
        let incoming = ScanPricingPolicy.Resolution(conditionPrice: Decimal(string: "7.50"), isApproximatePrice: true)

        let merged = ScanPricingPolicy.merge(existing: existing, incoming: incoming)

        #expect(merged == incoming)
    }
}
