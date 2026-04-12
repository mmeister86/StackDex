import Foundation

enum CollectionSelectionPolicy {
    struct SelectionState: Sendable, Equatable {
        var activeCollectionID: UUID?
        var pinnedDefaultCollectionID: UUID?

        init(activeCollectionID: UUID? = nil, pinnedDefaultCollectionID: UUID? = nil) {
            self.activeCollectionID = activeCollectionID
            self.pinnedDefaultCollectionID = pinnedDefaultCollectionID
        }
    }

    struct ResolvedSelection: Sendable, Equatable {
        var activeCollectionID: UUID?
        var pinnedDefaultCollectionID: UUID?

        var hasSelectableCollection: Bool {
            activeCollectionID != nil || pinnedDefaultCollectionID != nil
        }
    }

    static func resolve(
        state: SelectionState,
        existingCollectionIDs: [UUID]
    ) -> ResolvedSelection {
        let validIDs = Set(existingCollectionIDs)
        let sanitizedPinned = state.pinnedDefaultCollectionID.flatMap { validIDs.contains($0) ? $0 : nil }
        let sanitizedActive = state.activeCollectionID.flatMap { validIDs.contains($0) ? $0 : nil }

        return ResolvedSelection(
            activeCollectionID: sanitizedActive,
            pinnedDefaultCollectionID: sanitizedPinned
        )
    }

    static func collectionIDForOpening(
        state: SelectionState,
        existingCollectionIDs: [UUID]
    ) -> UUID? {
        let resolved = resolve(state: state, existingCollectionIDs: existingCollectionIDs)
        return resolved.activeCollectionID
            ?? resolved.pinnedDefaultCollectionID
            ?? existingCollectionIDs.first
    }

    static func saveTargetCollectionID(
        state: SelectionState,
        existingCollectionIDs: [UUID]
    ) -> UUID? {
        let resolved = resolve(state: state, existingCollectionIDs: existingCollectionIDs)
        return resolved.pinnedDefaultCollectionID
            ?? resolved.activeCollectionID
            ?? existingCollectionIDs.first
    }

    static func resolveAfterDeletingCollection(
        deletedCollectionID: UUID,
        state: SelectionState,
        remainingCollectionIDs: [UUID]
    ) -> ResolvedSelection {
        let stateWithoutDeleted = SelectionState(
            activeCollectionID: state.activeCollectionID == deletedCollectionID ? nil : state.activeCollectionID,
            pinnedDefaultCollectionID: state.pinnedDefaultCollectionID == deletedCollectionID ? nil : state.pinnedDefaultCollectionID
        )

        let resolved = resolve(state: stateWithoutDeleted, existingCollectionIDs: remainingCollectionIDs)

        let fallbackActive = resolved.activeCollectionID
            ?? resolved.pinnedDefaultCollectionID
            ?? remainingCollectionIDs.first

        return ResolvedSelection(
            activeCollectionID: fallbackActive,
            pinnedDefaultCollectionID: resolved.pinnedDefaultCollectionID
        )
    }
}
