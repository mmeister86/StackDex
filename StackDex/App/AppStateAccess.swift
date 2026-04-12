import Foundation
import SwiftData

enum AppStateAccess {
    static func primary(in context: ModelContext) -> AppStateEntity {
        var descriptor = FetchDescriptor<AppStateEntity>()
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let state = AppStateEntity()
        context.insert(state)
        try? context.save()
        return state
    }

    static func resolvedSelection(
        in context: ModelContext,
        collections: [CollectionEntity]
    ) -> CollectionSelectionPolicy.ResolvedSelection {
        let state = primary(in: context)
        let policyState = CollectionSelectionPolicy.SelectionState(
            activeCollectionID: state.activeCollectionID,
            pinnedDefaultCollectionID: state.pinnedDefaultCollectionID
        )
        return CollectionSelectionPolicy.resolve(
            state: policyState,
            existingCollectionIDs: collections.map(\.id)
        )
    }

    static func defaultCollectionID(
        in context: ModelContext,
        collections: [CollectionEntity]
    ) -> UUID? {
        let state = primary(in: context)
        return CollectionSelectionPolicy.collectionIDForOpening(
            state: .init(
                activeCollectionID: state.activeCollectionID,
                pinnedDefaultCollectionID: state.pinnedDefaultCollectionID
            ),
            existingCollectionIDs: collections.map(\.id)
        )
    }

    static func defaultSaveTargetCollectionID(
        in context: ModelContext,
        collections: [CollectionEntity]
    ) -> UUID? {
        let state = primary(in: context)
        return CollectionSelectionPolicy.saveTargetCollectionID(
            state: .init(
                activeCollectionID: state.activeCollectionID,
                pinnedDefaultCollectionID: state.pinnedDefaultCollectionID
            ),
            existingCollectionIDs: collections.map(\.id)
        )
    }

    static func setActiveCollectionID(_ collectionID: UUID?, in context: ModelContext) {
        let state = primary(in: context)
        state.activeCollectionID = collectionID
        try? context.save()
    }

    static func setPinnedCollectionID(_ collectionID: UUID?, in context: ModelContext) {
        let state = primary(in: context)
        state.pinnedDefaultCollectionID = collectionID
        try? context.save()
    }

    static func resolveAfterDeletion(
        deletedCollectionID: UUID,
        in context: ModelContext,
        remainingCollectionIDs: [UUID]
    ) {
        let state = primary(in: context)
        let resolved = CollectionSelectionPolicy.resolveAfterDeletingCollection(
            deletedCollectionID: deletedCollectionID,
            state: .init(
                activeCollectionID: state.activeCollectionID,
                pinnedDefaultCollectionID: state.pinnedDefaultCollectionID
            ),
            remainingCollectionIDs: remainingCollectionIDs
        )
        state.activeCollectionID = resolved.activeCollectionID
        state.pinnedDefaultCollectionID = resolved.pinnedDefaultCollectionID
        try? context.save()
    }
}
