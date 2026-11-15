import XCTest

final class OpenTTDPadUITests: XCTestCase {
    private let bundleIdentifier = "org.openttd.OpenTTDPad"

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchGame(environment: [String: String] = [:]) -> XCUIApplication {
        /* OpenTTDPad is landscape-only. Newer Simulators otherwise report
         * element frames in the device's portrait coordinates. */
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        /* Null music and sound drivers keep automated runs silent. */
        app.launchArguments = ["-g", "-G", "1", "-m", "null", "-s", "null"]
        app.launchEnvironment = ["OPENTTDPAD_SKIP_HINTS": "1"].merging(environment) { _, requested in requested }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        sleep(3)
        return app
    }

    private func constructionToolbarShift(for surface: XCUIElement) -> CGFloat {
        /* The upstream toolbar centers its fixed-size icon group on the wide
         * Pro canvas; base and mini layouts keep the compact origin. */
        return min(surface.frame.width, surface.frame.height) > 900 ? 0.042 : 0
    }

    func testFirstRunTouchCoachIsDismissibleAndNonBlocking() {
        let app = launchGame(environment: ["OPENTTDPAD_FORCE_HINTS": "1"])
        let dismiss = app.buttons["Got it"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
        dismiss.tap()
        XCTAssertFalse(dismiss.waitForExistence(timeout: 1))
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func testOneFingerMapMoveAndLongPressPrecision() throws {
        let app = launchGame()
        let surface = app.windows.firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))

        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.62)).tap()
        attachScreenshot("OpenTTDPad visible one-finger cursor")

        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.70))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.44))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        let precision = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.62))
        precision.press(forDuration: 0.65)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "OpenTTDPad after suppressed one-finger map move and precision press"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTouchOnlyConstructionToolsAndCancellation() {
        let app = launchGame()
        let surface = app.windows.firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))

        /* Top-toolbar taps use touch coordinates, not synthetic mouse input. */
        let toolbarShift = constructionToolbarShift(for: surface)
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.685 + toolbarShift, dy: 0.025)).tap()
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.84, dy: 0.065)).tap()
        sleep(1)
        let options = app.buttons["OpenTTDPad options"]
        XCTAssertEqual(options.value as? String, "Rail construction palette open")

        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        opened.name = "Rail construction palette opened by touch"
        opened.lifetime = .keepAlways
        add(opened)

        /* Autorail is the fifth tool in the right-aligned construction palette. */
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.629, dy: 0.093)).tap()
        let cancel = app.buttons["Cancel active construction tool"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)

        /* Left/right placement must update an already-active construction
         * control, not only the options button on the next launch. */
        let cancelStartedOnLeft = cancel.frame.midX < surface.frame.midX
        options.tap()
        app.buttons["Touch Controls"].tap()
        let controlSide = app.segmentedControls["Controls side"]
        XCTAssertTrue(controlSide.waitForExistence(timeout: 2))
        controlSide.buttons[cancelStartedOnLeft ? "Right" : "Left"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()
        XCTAssertNotEqual(cancel.frame.midX < surface.frame.midX, cancelStartedOnLeft)

        /* A direct construction drag must remain one continuous contact. */
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.73))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.53, dy: 0.73))
        start.press(forDuration: 0.12, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        cancel.tap()
        XCTAssertFalse(cancel.waitForExistence(timeout: 2))
        XCTAssertEqual(app.state, .runningForeground)

        /* Restore the persisted preference so every scenario is isolated. */
        options.tap()
        app.buttons["Touch Controls"].tap()
        let restoredControlSide = app.segmentedControls["Controls side"]
        XCTAssertTrue(restoredControlSide.waitForExistence(timeout: 2))
        restoredControlSide.buttons[cancelStartedOnLeft ? "Left" : "Right"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()
    }

    func testTouchOnlyRoadConstructionAndCancellation() {
        let app = launchGame()
        let surface = app.windows.firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))

        let toolbarShift: CGFloat = min(surface.frame.width, surface.frame.height) > 900 ? 0.031 : 0
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.727 + toolbarShift, dy: 0.025)).tap()
        let menu = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        menu.name = "Road toolbar menu opened by touch"
        menu.lifetime = .keepAlways
        add(menu)
        let menuY: CGFloat = min(surface.frame.width, surface.frame.height) > 900 ? 0.055 : 0.065
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.84, dy: menuY)).tap()
        sleep(1)
        let opened = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        opened.name = "Road construction palette opened by touch"
        opened.lifetime = .keepAlways
        add(opened)
        let options = app.buttons["OpenTTDPad options"]
        XCTAssertEqual(options.value as? String, "Road construction palette open")

        /* Autoroad uses the same direct-drag path as rail, but a distinct
         * upstream construction window and placement command. */
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.629, dy: 0.093)).tap()
        let cancel = app.buttons["Cancel active construction tool"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))

        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.34, dy: 0.68))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.68))
        start.press(forDuration: 0.12, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        cancel.tap()
        XCTAssertFalse(cancel.waitForExistence(timeout: 2))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testBackgroundAndForegroundRoundTrip() {
        let app = launchGame()
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
    }

    func testNativeOptionsTouchSettingsAndNotices() {
        let app = launchGame()
        let surface = app.windows.firstMatch
        let options = app.buttons["OpenTTDPad options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        XCTAssertTrue(options.isHittable)
        /* The landscape game is projected through XCTest's portrait host, so
         * its external accessibility frame is smaller than UIKit's 44 pt
         * source frame. Guard against the former oversized 66 pt projection. */
        XCTAssertGreaterThanOrEqual(options.frame.width, 30)
        XCTAssertGreaterThanOrEqual(options.frame.height, 30)
        XCTAssertLessThanOrEqual(options.frame.width, 46)
        XCTAssertGreaterThan(options.frame.midY, surface.frame.height * 0.75)
        options.tap()
        XCTAssertTrue(app.buttons["Touch Controls"].waitForExistence(timeout: 2))
        attachScreenshot("01 OpenTTDPad options")
        options.tap()
        XCTAssertFalse(app.buttons["Touch Controls"].waitForExistence(timeout: 1))
        options.tap()
        XCTAssertTrue(app.buttons["Touch Controls"].waitForExistence(timeout: 2))
        app.buttons["Touch Controls"].tap()

        XCTAssertTrue(app.navigationBars["Touch Controls"].waitForExistence(timeout: 3))
        let response = app.segmentedControls["Gesture response"]
        let precision = app.segmentedControls["Precision hold"]
        let targets = app.switches["Enlarged controls"]
        let momentum = app.switches["Map glide"]
        let side = app.segmentedControls["Controls side"]
        let haptics = app.switches["Haptics"]
        XCTAssertTrue(response.exists)
        XCTAssertTrue(precision.exists)
        XCTAssertTrue(targets.exists)
        XCTAssertTrue(momentum.exists)
        XCTAssertTrue(side.exists)
        XCTAssertTrue(haptics.exists)
        attachScreenshot("02 OpenTTDPad touch controls")

        let startedOnLeft = options.frame.midX < surface.frame.midX
        side.buttons[startedOnLeft ? "Right" : "Left"].tap()
        XCTAssertNotEqual(options.frame.midX < surface.frame.midX, startedOnLeft)
        side.buttons[startedOnLeft ? "Left" : "Right"].tap()
        XCTAssertEqual(options.frame.midX < surface.frame.midX, startedOnLeft)

        let originalHapticsValue = haptics.value as? String
        haptics.tap()
        XCTAssertNotEqual(haptics.value as? String, originalHapticsValue)
        haptics.tap()
        XCTAssertEqual(haptics.value as? String, originalHapticsValue)
        app.buttons["Done"].tap()
        options.tap()
        XCTAssertTrue(app.buttons["Licenses & Credits"].waitForExistence(timeout: 2))
        app.buttons["Licenses & Credits"].tap()
        XCTAssertTrue(app.navigationBars["Licenses & Credits"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textViews["OpenTTDPad licenses and credits"].exists)
        XCTAssertTrue(app.segmentedControls["License section"].exists)
        attachScreenshot("03 OpenTTDPad licenses and credits")
        app.segmentedControls["License section"].buttons["OpenTTD License"].tap()
        let licenseText = app.textViews["OpenTTDPad licenses and credits"].value as? String ?? ""
        XCTAssertFalse(licenseText.contains("###"))
        XCTAssertFalse(licenseText.contains("**0.**"))
        attachScreenshot("04 OpenTTD license")
        app.buttons["Done"].tap()
    }

    func testExportAllSavesPresentsZipShareSheet() {
        let app = launchGame()
        /* Backgrounding creates the lifecycle recovery save, so this scenario
         * is deterministic even on a brand-new Simulator data container. */
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        /* The iPad Dock remains an external accessibility overlay briefly
         * after activation and can swallow a lower-corner tap even though
         * XCTest already reports the app as foreground. */
        sleep(1)

        let options = app.buttons["OpenTTDPad options"]
        let export = app.buttons["Export All Saves"]
        options.tap()
        guard export.waitForExistence(timeout: 5) else {
            XCTFail("OpenTTDPad options did not expose save export")
            return
        }
        export.tap()
        XCTAssertTrue(app.windows.element(boundBy: 1).waitForExistence(timeout: 5))
    }
}
