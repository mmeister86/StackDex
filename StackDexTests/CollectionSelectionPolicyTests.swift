import Foundation
import Testing
@testable import StackDex

struct CollectionSelectionPolicyTests {
    @Test func saveTargetPrefersPinnedCollection() {
        let first = UUID()
        let pinned = UUID()
        let state = CollectionSelectionPolicy.SelectionState(
            activeCollectionID: first,
            pinnedDefaultCollectionID: pinned
        )

        let target = CollectionSelectionPolicy.saveTargetCollectionID(
            state: state,
            existingCollectionIDs: [first, pinned]
        )

        #expect(target == pinned)
    }

    @Test func saveTargetFallsBackToActiveThenFirstAvailable() {
        let first = UUID()
        let second = UUID()

        let activeState = CollectionSelectionPolicy.SelectionState(activeCollectionID: second)
        let activeTarget = CollectionSelectionPolicy.saveTargetCollectionID(
            state: activeState,
            existingCollectionIDs: [first, second]
        )
        #expect(activeTarget == second)

        let emptyState = CollectionSelectionPolicy.SelectionState()
        let firstAvailableTarget = CollectionSelectionPolicy.saveTargetCollectionID(
            state: emptyState,
            existingCollectionIDs: [first, second]
        )
        #expect(firstAvailableTarget == first)
    }

    @Test func deletingPinnedCollectionFallsBackToLastActiveRemaining() {
        let pinned = UUID()
        let active = UUID()
        let remaining = UUID()

        let result = CollectionSelectionPolicy.resolveAfterDeletingCollection(
            deletedCollectionID: pinned,
            state: .init(activeCollectionID: active, pinnedDefaultCollectionID: pinned),
            remainingCollectionIDs: [active, remaining]
        )

        #expect(result.pinnedDefaultCollectionID == nil)
        #expect(result.activeCollectionID == active)
    }

    @Test func deletingLastCollectionReturnsNoSelection() {
        let deleted = UUID()
        let result = CollectionSelectionPolicy.resolveAfterDeletingCollection(
            deletedCollectionID: deleted,
            state: .init(activeCollectionID: deleted, pinnedDefaultCollectionID: deleted),
            remainingCollectionIDs: []
        )

        #expect(result.activeCollectionID == nil)
        #expect(result.pinnedDefaultCollectionID == nil)
    }
}
