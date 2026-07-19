import XCTest

final class OpenTTDPadUITests: XCTestCase {
    private let bundleIdentifier = "org.openttd.OpenTTDPad"

    private func launchGame(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleIdentifier)
        app.launchArguments = ["-g", "-G", "1"]
        app.launchEnvironment = environment
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
        sleep(3)
        return app
    }

    func testFirstRunTouchCoachIsDismissibleAndNonBlocking() {
        let app = launchGame(environment: ["OPENTTDPAD_FORCE_HINTS": "1"])
        let dismiss = app.buttons["Got it"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
        dismiss.tap()
        XCTAssertFalse(dismiss.waitForExistence(timeout: 1))
        XCTAssertTrue(app.windows.firstMatch.exists)
    }

    func testContinuousMapDragAndLongPress() throws {
        let app = launchGame()
        let surface = app.windows.firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))

        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.70))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.44))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        let precision = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.62))
        precision.press(forDuration: 0.65)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "OpenTTDPad after continuous drag and precision press"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBackgroundAndForegroundRoundTrip() {
        let app = launchGame()
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 8))
    }
}
