import Foundation

enum ScanSavePlanner {
    enum StackDecision: Equatable {
        case merge(intoStackID: UUID)
        case createNewStack
    }

    static func resolveStackDecision(
        identity: CardIdentity,
        targetCollectionID: UUID,
        existingStacks: [CollectionRules.ExistingStackRecord],
        explicitSeparateStack: Bool
    ) -> StackDecision {
        if let mergeStackID = CollectionRules.mergeTargetStackID(
            for: identity,
            in: targetCollectionID,
            existingStacks: existingStacks,
            explicitSeparateStack: explicitSeparateStack
        ) {
            return .merge(intoStackID: mergeStackID)
        }

        return .createNewStack
    }
}
