import XCTest

final class CollectionFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest-in-memory", "-uitest-mock-lookup"]
        app.launch()
    }

    @MainActor
    func testCreatePinActivateAndOpenCollection() throws {
        let collectionName = "UI Sammlung"

        app.tabBars.buttons["Einstellungen"].tap()

        let nameField = app.textFields["settings.create.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(collectionName)

        let createButton = app.buttons["settings.create.submit"]
        XCTAssertTrue(createButton.isHittable)
        createButton.tap()

        let actionsButton = app.buttons["Aktionen \(collectionName)"]
        XCTAssertTrue(actionsButton.waitForExistence(timeout: 2))
        actionsButton.tap()
        app.buttons["Als aktiv setzen"].tap()

        app.tabBars.buttons["Sammlung"].tap()
        XCTAssertTrue(app.staticTexts[collectionName].waitForExistence(timeout: 2))
    }
}
