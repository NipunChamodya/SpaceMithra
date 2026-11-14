import XCTest

final class SmokeTests: XCTestCase {
    @MainActor func testAllSevenLanguagesLoadTheirOwnWelcomeResources() throws {
        let expected=[("si","මගේ Mac පරිලෝකනය කරන්න"),("ta","என் Mac ஐ வருடு"),("en","Scan My Mac"),("hi","मेरा Mac स्कैन करें"),("ar","فحص جهاز Mac"),("fr","Analyser mon Mac"),("zh-Hans","扫描我的 Mac")]
        let app=XCUIApplication()
        for (language,label) in expected {
            app.launchArguments=["--ui-testing","-language",language,"-showAdvanced","NO"]
            app.launch()
            if !app.windows.firstMatch.waitForExistence(timeout:3) {app.typeKey("n",modifierFlags:.command)}
            XCTAssertTrue(app.buttons["scanMyMac"].waitForExistence(timeout:15),language)
            XCTAssertEqual(app.buttons["scanMyMac"].label,label,language)
            let image=XCTAttachment(screenshot:app.windows.firstMatch.screenshot());image.name="welcome-"+language;image.lifetime = .keepAlways;add(image)
            app.terminate()
        }
    }

    @MainActor func testWelcomeAndKeyboardAccessibleNavigation() throws {
        let app=XCUIApplication()
        app.launchArguments=["--ui-testing","-language","en","-showAdvanced","NO"]
        app.launch()
        // Some desktop sessions restore the test process without a document window.
        if !app.windows.firstMatch.waitForExistence(timeout:3) {app.typeKey("n",modifierFlags:.command)}
        XCTAssertTrue(app.buttons["scanMyMac"].waitForExistence(timeout:15))
        XCTAssertTrue(app.popUpButtons["languagePicker"].exists)
        app.typeKey(.tab,modifierFlags:[])
        app.buttons["nav.settings"].click()
        XCTAssertTrue(app.staticTexts["Language"].exists)
        app.buttons["nav.queue"].click()
        XCTAssertTrue(app.buttons["Review selected files…"].exists)
        XCTAssertFalse(app.buttons["Review selected files…"].isEnabled)
    }
    @MainActor func testReadOnlyFixtureScanAndApplicationsOverview() throws {
        let marker=URL(fileURLWithPath:"/private/tmp/SpaceMithra-UITest-Fixtures/current-fixture.txt")
        guard let path=try? String(contentsOf:marker,encoding:.utf8) else {throw XCTSkip("Run python3 scripts/prepare_ui_fixture.py before UI acceptance")}
        let root=URL(fileURLWithPath:path,isDirectory:true)
        guard root.deletingLastPathComponent().path == "/private/tmp/SpaceMithra-UITest-Fixtures",
              FileManager.default.fileExists(atPath:root.appendingPathComponent("fixture-owner.txt").path) else {throw XCTSkip("Missing isolated UI fixture")}
        let app=XCUIApplication()
        app.launchArguments=["--ui-testing","--ui-fixture-root",root.path,"--ui-auto-scan","-language","en"]
        app.launch()
        // Some desktop sessions restore the test process without a document window.
        if !app.windows.firstMatch.waitForExistence(timeout:3) {app.typeKey("n",modifierFlags:.command)}
        XCTAssertTrue(app.staticTexts["storageOverview"].waitForExistence(timeout:20))
        let overview=XCTAttachment(screenshot:app.windows.firstMatch.screenshot());overview.name="storage-overview";overview.lifetime = .keepAlways;add(overview)
        app.buttons["nav.applications"].click()
        XCTAssertTrue(app.buttons["application.org.spacemithra.fixture"].waitForExistence(timeout:10))
        let apps=XCTAttachment(screenshot:app.windows.firstMatch.screenshot());apps.name="applications-overview";apps.lifetime = .keepAlways;add(apps)
        XCTAssertFalse(app.staticTexts["Info.plist"].exists)
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Applications/Example.app/Contents/Info.plist").path))
    }
}
