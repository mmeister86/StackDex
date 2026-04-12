import Foundation

enum CollectionRules {
    enum AddBehavior: Sendable {
        case mergeIntoExistingStack
        case createSeparateStack
    }

    enum MoveCopyConflictBehavior: Sendable {
        case keepSeparateParallelStack
    }

    struct ExistingStackRecord: Hashable, Sendable {
        let stackID: UUID
        let collectionID: UUID
        let canonicalCardID: String

        init(stackID: UUID, collectionID: UUID, canonicalCardID: String) {
            self.stackID = stackID
            self.collectionID = collectionID
            self.canonicalCardID = canonicalCardID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static let moveCopyConflictBehavior: MoveCopyConflictBehavior = .keepSeparateParallelStack

    static func addBehavior(explicitSeparateStack: Bool) -> AddBehavior {
        explicitSeparateStack ? .createSeparateStack : .mergeIntoExistingStack
    }

    static func mergeTargetStackID(
        for identity: CardIdentity,
        in collectionID: UUID,
        existingStacks: [ExistingStackRecord],
        explicitSeparateStack: Bool
    ) -> UUID? {
        guard addBehavior(explicitSeparateStack: explicitSeparateStack) == .mergeIntoExistingStack else {
            return nil
        }

        return existingStacks
            .first(where: { $0.collectionID == collectionID && $0.canonicalCardID == identity.canonicalCardID })?
            .stackID
    }
}
