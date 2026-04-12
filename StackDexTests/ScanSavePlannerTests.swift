import Foundation
import Testing
@testable import StackDex

struct ScanSavePlannerTests {
    @Test func defaultBehaviorMergesWhenStackExists() {
        let collectionID = UUID()
        let existingStackID = UUID()
        let identity = CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu")

        let decision = ScanSavePlanner.resolveStackDecision(
            identity: identity,
            targetCollectionID: collectionID,
            existingStacks: [
                .init(stackID: existingStackID, collectionID: collectionID, canonicalCardID: "sv2-199"),
            ],
            explicitSeparateStack: false
        )

        #expect(decision == .merge(intoStackID: existingStackID))
    }

    @Test func explicitSeparateForcesNewStack() {
        let collectionID = UUID()
        let identity = CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu")

        let decision = ScanSavePlanner.resolveStackDecision(
            identity: identity,
            targetCollectionID: collectionID,
            existingStacks: [
                .init(stackID: UUID(), collectionID: collectionID, canonicalCardID: "sv2-199"),
            ],
            explicitSeparateStack: true
        )

        #expect(decision == .createNewStack)
    }
}
