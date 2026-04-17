import Foundation
import SwiftData

@Model
final class AppStateEntity {
    var id: UUID
    var activeCollectionID: UUID?
    var pinnedDefaultCollectionID: UUID?
    var scanOCRQualityPresetRawValue: String?
    var scanOCRPostProcessModeRawValue: String?

    init(
        id: UUID = UUID(),
        activeCollectionID: UUID? = nil,
        pinnedDefaultCollectionID: UUID? = nil,
        scanOCRQualityPresetRawValue: String? = nil,
        scanOCRPostProcessModeRawValue: String? = nil
    ) {
        self.id = id
        self.activeCollectionID = activeCollectionID
        self.pinnedDefaultCollectionID = pinnedDefaultCollectionID
        self.scanOCRQualityPresetRawValue = scanOCRQualityPresetRawValue
        self.scanOCRPostProcessModeRawValue = scanOCRPostProcessModeRawValue
    }
}
