import Foundation
import SwiftData
import Testing
@testable import StackDex

@MainActor
struct AppStateAccessScanSettingsTests {
    @Test func defaultFallbackUsesExpectedScannerSettings() throws {
        let context = try makeInMemoryContext()

        let qualityPreset = AppStateAccess.scanOCRQualityPreset(in: context)
        let postProcessMode = AppStateAccess.scanOCRPostProcessMode(in: context)

        #expect(qualityPreset == .maximum)
        #expect(postProcessMode == .visionOnly)
    }

    @Test func persistedRawValuesRoundTripThroughTypedAccessors() throws {
        let context = try makeInMemoryContext()

        AppStateAccess.setScanOCRQualityPreset(.fast, in: context)
        AppStateAccess.setScanOCRPostProcessMode(.visionWithPostProcessing, in: context)

        #expect(AppStateAccess.scanOCRQualityPreset(in: context) == .fast)
        #expect(AppStateAccess.scanOCRPostProcessMode(in: context) == .visionWithPostProcessing)
    }

    @Test func invalidRawValuesFallBackToDefaults() throws {
        let context = try makeInMemoryContext()
        let state = AppStateAccess.primary(in: context)
        state.scanOCRQualityPresetRawValue = "not-a-valid-preset"
        state.scanOCRPostProcessModeRawValue = "not-a-valid-mode"
        try context.save()

        #expect(AppStateAccess.scanOCRQualityPreset(in: context) == .maximum)
        #expect(AppStateAccess.scanOCRPostProcessMode(in: context) == .visionOnly)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([AppStateEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
