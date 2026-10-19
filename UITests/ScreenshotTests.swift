import XCTest

/// Captures every screen in both languages into a folder, for visual review.
/// Skipped in normal test runs; to capture, pass the folder through the test runner:
///
///     TEST_RUNNER_SCREENSHOTS_DIR="$PWD/Screenshots" xcodebuild test -project Luzhanqi.xcodeproj \
///       -scheme Luzhanqi -destination 'platform=iOS Simulator,name=Luzhanqi Tests' \
///       -only-testing:LuzhanqiUITests/ScreenshotTests
///
/// Each screen is opened with the debug-only `-demo` launch option, and the shot
/// is taken once that screen's key control has appeared.
@MainActor
final class ScreenshotTests: XCTestCase {
    /// File name, launch arguments, and the element that shows the screen is ready.
    let screens: [(name: String, arguments: [String], ready: String)] = [
        ("home", [], "home.startComputer"),
        ("settings", ["-demo", "settings"], "settings.done"),
        ("deploy", ["-demo", "deploy"], "deploy.ready"),
        ("deploy-error", ["-demo", "deploy-error"], "deploy.ready"),
        ("handoff", ["-demo", "handoff"], "handoff.title"),
        ("turn", ["-demo", "turn"], "game.endTurn"),
        ("game", ["-demo", "game"], "game.slip"),
        ("over", ["-demo", "over"], "game.over.title"),
        ("rules", ["-demo", "rules"], "rules.board"),
        ("rules-pieces", ["-demo", "rules", "-rulesAnchor", "pieces"], "rules.pieces"),
        ("rules-examples", ["-demo", "rules", "-rulesAnchor", "examples"], "rules.examples"),
    ]

    func testCaptureEveryScreen() throws {
        guard let folder = ProcessInfo.processInfo.environment["SCREENSHOTS_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_SCREENSHOTS_DIR to capture screenshots")
        }
        for (language, suffix) in [("english", ""), ("chinese", "-zh")] {
            for screen in screens {
                let app = XCUIApplication()
                app.launchArguments = ["-uiTesting", "-language", language] + screen.arguments
                app.launch()
                XCTAssertTrue(app.descendants(matching: .any)[screen.ready].firstMatch.waitForExistence(timeout: 15),
                              "\(screen.name) (\(language)) never showed \(screen.ready)")
                Thread.sleep(forTimeInterval: 1)  // let animations settle
                let url = URL(fileURLWithPath: folder).appending(path: "\(screen.name)\(suffix).png")
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
                app.terminate()
            }
        }
    }
}
