import XCTest

final class ScanFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest-in-memory", "-uitest-seed-collection", "-uitest-mock-lookup"]
        app.launch()
    }

    @MainActor
    func testManualLookupCandidateSelectionAndSave() throws {
        let scanTab = app.tabBars.buttons["Scannen"]
        XCTAssertTrue(scanTab.waitForExistence(timeout: 2))
        scanTab.tap()

        let identifiedField = app.textFields["scan.manual.query"]
        let placeholderField = app.textFields["Name, Set oder Nummer"]
        if !identifiedField.exists && !placeholderField.exists {
            app.swipeUp()
        }

        let queryField = identifiedField.exists ? identifiedField : (placeholderField.exists ? placeholderField : app.textFields.firstMatch)
        XCTAssertTrue(queryField.waitForExistence(timeout: 2))
        queryField.tap()
        queryField.typeText("pikachu")

        app.buttons["scan.manual.submit"].tap()

        let pikachuCandidate = app.buttons["scan.candidate.Pikachu"]
        XCTAssertTrue(pikachuCandidate.waitForExistence(timeout: 3))
        pikachuCandidate.tap()

        let saveButton = app.buttons["scan.save.submit"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        let saveMessage = app.staticTexts["scan.info.message"]
        XCTAssertTrue(saveMessage.waitForExistence(timeout: 2))

        app.tabBars.buttons["Sammlung"].tap()
        XCTAssertFalse(app.staticTexts["Noch keine Karten"].exists)
    }
}
