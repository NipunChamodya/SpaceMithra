import XCTest

final class SmokeTests: XCTestCase {
    @MainActor func testLaunchAndKeyboardAccessibleNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-onboarded", "YES", "-language", "en"]
        app.launch()
        XCTAssertTrue(app.buttons["chooseFolder"].waitForExistence(timeout: 10))
        app.buttons["nav.settings"].click()
        XCTAssertTrue(app.staticTexts["Language"].exists)
        app.buttons["nav.queue"].click()
        XCTAssertTrue(app.buttons["Review selected files…"].exists)
        XCTAssertFalse(app.buttons["Review selected files…"].isEnabled)
    }
}
