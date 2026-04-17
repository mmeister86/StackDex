import XCTest

final class ScanFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let baseLaunchArguments = ["-uitest-in-memory", "-uitest-seed-collection", "-uitest-mock-lookup"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launchApp(extraArguments: [String] = []) {
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = baseLaunchArguments + extraArguments
        app.launch()
    }

    @MainActor
    func testManualLookupCandidateSelectionAndSave() throws {
        launchApp()

        let scanTab = app.tabBars.buttons["Scannen"]
        XCTAssertTrue(scanTab.waitForExistence(timeout: 2))
        scanTab.tap()

        let openSheet = app.buttons["scan.sheet.open"]
        XCTAssertTrue(openSheet.waitForExistence(timeout: 4))
        openSheet.tap()

        let identifiedField = app.textFields["scan.manual.query"]
        let placeholderField = app.textFields["Name, Set oder Nummer"]
        let queryField = identifiedField.exists ? identifiedField : (placeholderField.exists ? placeholderField : app.textFields.firstMatch)
        XCTAssertTrue(queryField.waitForExistence(timeout: 4))
        queryField.tap()
        queryField.typeText("pikachu\n")

        let pikachuCandidate = app.buttons["scan.candidate.Pikachu"]
        XCTAssertTrue(pikachuCandidate.waitForExistence(timeout: 3))

        let saveButton = app.buttons["scan.save.submit"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        XCTAssertTrue(saveButton.isEnabled)
    }

    @MainActor
    func testScanScreenShowsGuidanceAndNoMatchMessaging() throws {
        launchApp()

        let scanTab = app.tabBars.buttons["Scannen"]
        XCTAssertTrue(scanTab.waitForExistence(timeout: 2))
        scanTab.tap()

        XCTAssertTrue(app.otherElements["scan.shell.root"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["scan.shell.capture"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["scan.shell.recentPhotoShortcut"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.otherElements["scan.shell.frame"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Karte innerhalb des Rahmens halten, Blendung vermeiden."].waitForExistence(timeout: 4))
        XCTAssertFalse(app.otherElements["scan.sheet.root"].exists)

        app.buttons["scan.sheet.open"].tap()
        XCTAssertTrue(app.otherElements["scan.sheet.root"].waitForExistence(timeout: 4))

        let identifiedField = app.textFields["scan.manual.query"]
        let placeholderField = app.textFields["Name, Set oder Nummer"]
        let queryField = identifiedField.exists ? identifiedField : (placeholderField.exists ? placeholderField : app.textFields.firstMatch)
        XCTAssertTrue(queryField.waitForExistence(timeout: 2))
        queryField.tap()
        queryField.typeText("unknown card\n")

        XCTAssertTrue(app.staticTexts["Kein passender Kartenkandidat gefunden."].waitForExistence(timeout: 3))
    }

    @MainActor
    func testOCRDebugTabExistsAndShowsEmptyStateInitially() throws {
        launchApp()

        let debugTab = app.tabBars.buttons["OCR Debug"]
        XCTAssertTrue(debugTab.waitForExistence(timeout: 3))
        debugTab.tap()

        XCTAssertTrue(app.staticTexts["Noch kein OCR-Lauf"].waitForExistence(timeout: 3))
    }

}
