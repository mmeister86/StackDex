import Foundation
import SwiftData

@Model
final class AppStateEntity {
    var id: UUID
    var activeCollectionID: UUID?
    var pinnedDefaultCollectionID: UUID?

    init(
        id: UUID = UUID(),
        activeCollectionID: UUID? = nil,
        pinnedDefaultCollectionID: UUID? = nil
    ) {
        self.id = id
        self.activeCollectionID = activeCollectionID
        self.pinnedDefaultCollectionID = pinnedDefaultCollectionID
    }
}
