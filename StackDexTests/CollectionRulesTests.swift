import Foundation
import Testing
@testable import StackDex

struct CollectionRulesTests {
    @Test func defaultAddMergesWithinSameCollectionByCanonicalID() {
        let collectionID = UUID()
        let matchingStackID = UUID()
        let otherCollectionID = UUID()

        let existing: [CollectionRules.ExistingStackRecord] = [
            .init(stackID: matchingStackID, collectionID: collectionID, canonicalCardID: "xy7-54"),
            .init(stackID: UUID(), collectionID: otherCollectionID, canonicalCardID: "xy7-54"),
        ]

        let target = CollectionRules.mergeTargetStackID(
            for: CardIdentity(canonicalCardID: "xy7-54", name: "Gardevoir"),
            in: collectionID,
            existingStacks: existing,
            explicitSeparateStack: false
        )

        #expect(target == matchingStackID)
    }

    @Test func defaultAddDoesNotMergeAcrossCollections() {
        let destinationCollectionID = UUID()
        let existing = [
            CollectionRules.ExistingStackRecord(
                stackID: UUID(),
                collectionID: UUID(),
                canonicalCardID: "swsh1-001"
            ),
        ]

        let target = CollectionRules.mergeTargetStackID(
            for: CardIdentity(canonicalCardID: "swsh1-001", name: "Grookey"),
            in: destinationCollectionID,
            existingStacks: existing,
            explicitSeparateStack: false
        )

        #expect(target == nil)
    }

    @Test func explicitSeparateStackSkipsMergeEvenWhenMatchExists() {
        let collectionID = UUID()
        let existing = [
            CollectionRules.ExistingStackRecord(
                stackID: UUID(),
                collectionID: collectionID,
                canonicalCardID: "sv2-199"
            ),
        ]

        let target = CollectionRules.mergeTargetStackID(
            for: CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu"),
            in: collectionID,
            existingStacks: existing,
            explicitSeparateStack: true
        )

        #expect(target == nil)
    }

    @Test func moveCopyConflictBehaviorKeepsParallelStacks() {
        #expect(CollectionRules.moveCopyConflictBehavior == .keepSeparateParallelStack)
    }
}
