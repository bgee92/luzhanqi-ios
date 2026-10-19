import XCTest

/// End-to-end tests that drive the app the way a player does. Each test starts
/// from a clean install (`-uiTesting` clears settings and the saved game).
@MainActor
final class LuzhanqiUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    @discardableResult
    func launch(language: String? = "english", reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-uiTesting"] : []) + (language.map { ["-language", $0] } ?? [])
        app.launch()
        return app
    }

    func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) did not appear", file: file, line: line)
    }

    /// Waits until an element's accessibility label contains `text`.
    func waitForLabel(_ element: XCUIElement, contains text: String, timeout: TimeInterval = 20,
                      file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       "label never contained '\(text)' (was '\(element.label)')", file: file, line: line)
    }

    var board: (XCUIApplication) -> XCUIElement { { $0.otherElements["board"].firstMatch } }

    /// Taps a square on the board, seen from Red's side (Red at the bottom).
    func tap(_ square: String, in app: XCUIApplication) {
        let col = Int(square.unicodeScalars.first!.value - Character("a").unicodeScalars.first!.value)
        let rank = Int(square.dropFirst())!
        let row = 12 - rank
        let slot = row <= 5 ? row : row + 1
        board(app).coordinate(withNormalizedOffset: CGVector(dx: (Double(col) * 100 + 50) / 500,
                                                             dy: (Double(slot) * 62 + 31) / 806)).tap()
    }

    func startComputerGame(_ app: XCUIApplication, difficulty: String = "easy") {
        element(app, "home.difficulty.\(difficulty)").tap()
        element(app, "home.startComputer").tap()
        waitFor(element(app, "deploy.ready"))
    }

    /// Red's front-row piece on a6 attacks Blue's front-row piece on a7. Always legal:
    /// a6 can't hold a mine, bomb or flag, and a7 is never a camp.
    func attackFromA6(_ app: XCUIApplication) {
        tap("a6", in: app)
        tap("a7", in: app)
    }

    // MARK: Home

    func testHomeShowsEveryControl() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["陆战棋"].exists)
        XCTAssertTrue(app.staticTexts["Play the computer"].exists)
        for id in ["home.language.english", "home.language.chinese", "home.difficulty.easy", "home.difficulty.medium",
                   "home.difficulty.hard", "home.moveFirst", "home.startComputer", "home.startPassAndPlay",
                   "home.rules", "home.settings"] {
            XCTAssertTrue(element(app, id).exists, "\(id) is missing")
        }
        XCTAssertFalse(element(app, "home.resume").exists, "No saved game on a clean install")
    }

    func testLanguageSwitchTranslatesEverythingAndPersists() {
        let app = launch()
        element(app, "home.language.chinese").tap()
        XCTAssertTrue(app.staticTexts["人机对战"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["开始对战"].exists)
        XCTAssertFalse(app.staticTexts["Play the computer"].exists)

        // Persists across launches (no -language override this time).
        app.terminate()
        let relaunched = launch(language: nil, reset: false)
        XCTAssertTrue(relaunched.staticTexts["人机对战"].waitForExistence(timeout: 5))

        // Game screens follow the language too.
        startComputerGame(relaunched)
        XCTAssertTrue(relaunched.staticTexts["点击两枚棋子交换位置。不能交换的棋子会变淡。"].exists)
        XCTAssertTrue(relaunched.buttons["就绪"].exists)
    }

    func testSettingsPersistAcrossLaunches() {
        let app = launch()
        element(app, "home.settings").tap()
        let open = element(app, "settings.openPieces")
        waitFor(open)
        XCTAssertEqual(open.value as? String, "0")
        open.switches.firstMatch.exists ? open.switches.firstMatch.tap() : open.tap()
        XCTAssertEqual(open.value as? String, "1")
        element(app, "settings.drawLimit").tap()
        app.buttons["Never"].firstMatch.tap()
        waitForLabel(element(app, "settings.drawLimit"), contains: "Never", timeout: 5)
        element(app, "settings.done").tap()

        app.terminate()
        let relaunched = launch(reset: false)
        element(relaunched, "home.settings").tap()
        waitFor(element(relaunched, "settings.openPieces"))
        XCTAssertEqual(element(relaunched, "settings.openPieces").value as? String, "1")
        waitForLabel(element(relaunched, "settings.drawLimit"), contains: "Never", timeout: 5)
    }

    // MARK: Deployment

    func testDeploymentSwapsWithoutMovingTheBoard() {
        let app = launch()
        startComputerGame(app)
        let frame = board(app).frame
        let hint = element(app, "deploy.hint")
        XCTAssertEqual(hint.label, "Tap two pieces to swap them. Pieces that can't swap are faded.")

        element(app, "deploy.shuffle").tap()
        element(app, "deploy.suggested").tap()
        XCTAssertEqual(board(app).frame, frame)

        // A legal swap of two front-row officers.
        let a6 = element(app, "piece.a6").label
        tap("a6", in: app)
        tap("b6", in: app)
        XCTAssertEqual(element(app, "piece.b6").label.components(separatedBy: " ").dropLast(2),
                       a6.components(separatedBy: " ").dropLast(2), "the a6 piece should now be on b6")
        XCTAssertEqual(board(app).frame, frame)

        // An illegal swap: the Flag can't leave its headquarters. The longest error must not move the board.
        let flag = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Red Flag'")).firstMatch
        let square = String(flag.label.split(separator: " ").last!)
        tap(square, in: app)
        tap("a6", in: app)
        XCTAssertEqual(hint.label, "The Flag must start in a headquarters.")
        XCTAssertEqual(board(app).frame, frame)
    }

    // MARK: Playing the computer

    func testFullGameAgainstTheComputer() {
        let app = launch()
        startComputerGame(app)
        element(app, "deploy.ready").tap()
        let status = element(app, "game.status")
        waitFor(status)
        XCTAssertTrue(status.label.contains("Your move"))
        let frame = board(app).frame

        attackFromA6(app)
        waitFor(element(app, "game.slip"))
        // The computer replies, then it's our move again.
        waitForLabel(status, contains: "Your move")
        XCTAssertEqual(board(app).frame, frame, "the board must not resize after a move")

        // Move log lists both moves.
        element(app, "game.menu").tap()
        element(app, "game.menu.log").tap()
        waitFor(element(app, "log.list"))
        XCTAssertGreaterThanOrEqual(app.cells.count, 2)
        element(app, "log.done").tap()

        // Rules open from the game.
        element(app, "game.rules").tap()
        waitFor(element(app, "rules.board"))
        app.swipeDown(velocity: .fast)

        // Save & quit, then resume from the home screen.
        element(app, "game.menu").tap()
        element(app, "game.menu.quit").tap()
        waitFor(element(app, "home.resume"))
        element(app, "home.resume").tap()
        waitForLabel(element(app, "game.status"), contains: "Your move")
        XCTAssertEqual(board(app).frame, frame, "the resumed game shows the same board")
    }

    func testResigningShowsDefeatAndRematchStartsANewGame() {
        let app = launch()
        startComputerGame(app)
        element(app, "deploy.ready").tap()
        waitFor(element(app, "game.status"))
        element(app, "game.menu").tap()
        element(app, "game.menu.resign").tap()
        app.buttons["Resign"].firstMatch.tap()
        let title = element(app, "game.over.title")
        waitFor(title)
        XCTAssertEqual(title.label, "Defeat")
        XCTAssertTrue(app.staticTexts["You resigned."].exists)
        element(app, "game.over.rematch").tap()
        waitFor(element(app, "deploy.ready"))
    }

    // MARK: Pass and play

    func testPassAndPlayHidesTheBoardBetweenTurns() {
        let app = launch()
        element(app, "home.startPassAndPlay").tap()
        waitFor(element(app, "deploy.ready"))
        XCTAssertTrue(app.staticTexts["Red · Deploy"].exists)
        element(app, "deploy.ready").tap()

        waitFor(element(app, "handoff.title"))
        XCTAssertEqual(element(app, "handoff.title").label, "Pass to Blue")
        XCTAssertFalse(board(app).exists, "the board must be hidden during a hand-off")
        element(app, "handoff.ready").tap()
        waitFor(app.staticTexts["Blue · Deploy"])
        element(app, "deploy.ready").tap()

        waitFor(element(app, "handoff.title"))
        XCTAssertEqual(element(app, "handoff.title").label, "Pass to Red")
        element(app, "handoff.ready").tap()
        waitFor(element(app, "game.status"))
        let frame = board(app).frame

        attackFromA6(app)
        let endTurn = element(app, "game.endTurn")
        XCTAssertTrue(endTurn.waitForExistence(timeout: 5) && endTurn.isHittable)
        XCTAssertEqual(endTurn.label, "Done — pass to Blue")
        XCTAssertEqual(board(app).frame, frame, "the end-turn button must not resize the board")
        endTurn.tap()
        waitFor(element(app, "handoff.title"))
        XCTAssertEqual(element(app, "handoff.title").label, "Pass to Blue")
        XCTAssertFalse(board(app).exists)
    }

    // MARK: Rules

    func testRulesPageInBothLanguages() {
        for (language, heading, example, piece) in [("english", "Railroads run straight", "Engineers turn corners", "Field Marshal"),
                                                    ("chinese", "铁路只能直行", "工兵可以转弯", "司令")] {
            let app = launch(language: language)
            element(app, "home.rules").tap()
            waitFor(element(app, "rules.board"))
            let pieces = element(app, "rules.pieces")
            for _ in 0..<6 where !pieces.exists || !pieces.isHittable { app.swipeUp() }
            XCTAssertTrue(app.staticTexts[piece].exists, "\(language): piece list")
            let examples = element(app, "rules.examples")
            for _ in 0..<8 where !examples.exists || !app.staticTexts[example].isHittable { app.swipeUp() }
            XCTAssertTrue(app.staticTexts[heading].exists, "\(language): railroad example")
            XCTAssertTrue(app.staticTexts[example].exists, "\(language): engineer example")
            app.terminate()
        }
    }
}
