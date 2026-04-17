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

    static func scanOCRQualityPreset(in context: ModelContext) -> ScanOCRQualityPreset {
        let state = primary(in: context)
        guard let rawValue = state.scanOCRQualityPresetRawValue else {
            return .maximum
        }
        return ScanOCRQualityPreset(rawValue: rawValue) ?? .maximum
    }

    static func setScanOCRQualityPreset(_ preset: ScanOCRQualityPreset, in context: ModelContext) {
        let state = primary(in: context)
        state.scanOCRQualityPresetRawValue = preset.rawValue
        try? context.save()
    }

    static func scanOCRPostProcessMode(in context: ModelContext) -> ScanOCRPostProcessMode {
        let state = primary(in: context)
        guard let rawValue = state.scanOCRPostProcessModeRawValue else {
            return .visionOnly
        }
        return ScanOCRPostProcessMode(rawValue: rawValue) ?? .visionOnly
    }

    static func setScanOCRPostProcessMode(_ mode: ScanOCRPostProcessMode, in context: ModelContext) {
        let state = primary(in: context)
        state.scanOCRPostProcessModeRawValue = mode.rawValue
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
