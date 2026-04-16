import CoreGraphics
import Testing
@testable import StackDex

struct CameraZoomConfigurationBuilderTests {
    @Test func dynamicStepsIncludeVirtualSwitchOversWithinScannerLimit() {
        let config = CameraZoomConfigurationBuilder.make(
            minAvailable: 1,
            maxAvailable: 6,
            switchOverFactors: [1.9, 2.95]
        )

        #expect(config.min == 1)
        #expect(config.max == 3)
        #expect(config.defaultZoom == 1)
        expectSteps(config.steps, equals: [1, 1.9, 2, 2.95, 3])
    }

    @Test func clampsZoomToMaximumThreeTimesForScannerQuality() {
        let config = CameraZoomConfigurationBuilder.make(
            minAvailable: 1,
            maxAvailable: 2.4,
            switchOverFactors: [2.8]
        )

        #expect(config.max == 2.4)
        expectSteps(config.steps, equals: [1, 2, 2.4])
    }

    @Test func fallbackWithoutVirtualSwitchOversStillProvidesUsefulSteps() {
        let config = CameraZoomConfigurationBuilder.make(
            minAvailable: 1,
            maxAvailable: 1.7,
            switchOverFactors: []
        )

        #expect(config.min == 1)
        #expect(config.max == 1.7)
        expectSteps(config.steps, equals: [1, 1.7])
    }

    private func expectSteps(_ actual: [CGFloat], equals expected: [CGFloat], tolerance: CGFloat = 0.001) {
        #expect(actual.count == expected.count)
        for (lhs, rhs) in zip(actual, expected) {
            #expect(abs(lhs - rhs) <= tolerance)
        }
    }
}
