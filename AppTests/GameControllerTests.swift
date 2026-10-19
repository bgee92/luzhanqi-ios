import Foundation
import LuzhanqiKit
import Testing
@testable import Luzhanqi

/// The game flow the screens drive: deployment, hand-offs, turns, the computer
/// opponent, resigning and autosave. Serialized because they share the autosave file.
@MainActor
@Suite(.serialized) struct GameControllerTests {
    init() { GameController.deleteSave() }

    // MARK: Helpers

    /// Waits for the computer opponent (it thinks on a background task).
    func waitForComputer(_ c: GameController, timeout: Duration = .seconds(20)) async {
        let deadline = ContinuousClock.now + timeout
        while c.aiThinking && ContinuousClock.now < deadline { try? await Task.sleep(for: .milliseconds(20)) }
    }

    func computerGame(human: Side = .red) -> GameController {
        GameController(mode: .computer(human: human, difficulty: .easy), rules: .standard)
    }

    /// Two of the viewer's pieces that may legally swap (two officers in the middle rows).
    func swappablePair(_ c: GameController, side: Side) -> (Position, Position) {
        let officers = c.draft.filter { pos, rank in
            rank.isOfficer && (2...4).contains(Board.localRow(side, pos)) && c.draft[pos] != nil
        }.map(\.key).sorted()
        return (officers[0], officers[1])
    }

    func playFirstLegalMove(_ c: GameController) -> Move {
        let move = c.playerView!.legalMoves().first!
        c.tapBoard(move.from)
        c.tapBoard(move.to)
        return move
    }

    // MARK: Deployment

    @Test func newComputerGameStartsWithALegalDraft() {
        let c = computerGame()
        #expect(c.phase == .deploying(.red))
        #expect(c.viewer == .red)
        #expect(c.state == nil)
        #expect(c.humanSide == .red)
        #expect(Setup.errors(in: c.draft, for: .red).isEmpty)
    }

    @Test func tappingTwoPiecesSwapsThem() {
        let c = computerGame()
        let (a, b) = swappablePair(c, side: .red)
        let (rankA, rankB) = (c.draft[a], c.draft[b])
        c.tapDeployment(a)
        #expect(c.selected == a)
        #expect(!c.swapTargets.isEmpty)
        c.tapDeployment(b)
        #expect(c.draft[a] == rankB && c.draft[b] == rankA)
        #expect(c.selected == nil)
        #expect(c.setupViolation == nil)
    }

    @Test func tappingTheSamePieceTwiceDeselects() {
        let c = computerGame()
        let (a, _) = swappablePair(c, side: .red)
        c.tapDeployment(a)
        c.tapDeployment(a)
        #expect(c.selected == nil)
    }

    @Test func illegalSwapIsRefusedWithAReason() {
        let c = computerGame()
        let flag = c.draft.first { $0.value == .flag }!.key
        let front = c.draft.first { Board.localRow(.red, $0.key) == 5 }!.key
        let before = c.draft
        c.tapDeployment(flag)
        c.tapDeployment(front)
        #expect(c.setupViolation == .flagOutsideHeadquarters)
        #expect(c.draft == before)
        #expect(!c.swapTargets.contains(front))
        c.tapDeployment(front)  // any new tap clears the message
        #expect(c.setupViolation == nil)
    }

    @Test func shuffleAndSuggestedGiveLegalArmies() {
        let c = computerGame()
        for _ in 0..<10 {
            c.shuffleDraft()
            #expect(Setup.errors(in: c.draft, for: .red).isEmpty)
            c.suggestDraft()
            #expect(Setup.errors(in: c.draft, for: .red).isEmpty)
        }
        #expect(c.selected == nil)
    }

    // MARK: Playing the computer

    @Test func readyStartsTheGameWithTheHumanToMove() {
        let c = computerGame()
        c.confirmDeployment()
        #expect(c.phase == .playing)
        #expect(c.state != nil)
        #expect(c.canMove)
        #expect(GameController.hasSave)
    }

    @Test func computerMovesFirstWhenTheHumanIsBlue() async {
        let c = computerGame(human: .blue)
        c.confirmDeployment()
        await waitForComputer(c)
        #expect(c.state?.history.count == 1)
        #expect(c.viewer == .blue && c.canMove)
        #expect(c.announcement?.record.side == .red)
    }

    @Test func aMoveIsAnsweredByTheComputer() async {
        let c = computerGame()
        c.confirmDeployment()
        let move = playFirstLegalMove(c)
        #expect(c.state?.history.first?.move == move)
        #expect(c.selected == nil)
        await waitForComputer(c)
        #expect(c.state!.history.count == 2 || c.phase == .over)
        #expect(c.canMove || c.phase == .over)
    }

    @Test func tapsThatAreNotMovesChangeNothing() {
        let c = computerGame()
        c.confirmDeployment()
        let view = c.playerView!
        // An enemy piece can't be selected.
        let enemy = Board.allPositions.first { view[$0]?.side == .blue }!
        c.tapBoard(enemy)
        #expect(c.selected == nil)
        // Selecting a piece then tapping an unreachable square only deselects.
        let move = view.legalMoves().first!
        c.tapBoard(move.from)
        #expect(c.selected == move.from)
        let unreachable = Board.allPositions.first { !view.destinations(from: move.from).contains($0) && view[$0] == nil }!
        c.tapBoard(unreachable)
        #expect(c.selected == nil)
        #expect(c.state?.history.isEmpty == true)
    }

    @Test func resigningEndsTheGameAndClearsTheSave() {
        let c = computerGame()
        c.confirmDeployment()
        c.resign()
        #expect(c.phase == .over)
        #expect(c.state?.result == .win(.blue, .resignation))
        #expect(!GameController.hasSave)
    }

    @Test func savedGameResumesWhereItStopped() async {
        let c = computerGame()
        c.confirmDeployment()
        _ = playFirstLegalMove(c)
        await waitForComputer(c)
        let resumed = try! #require(GameController.resume())
        #expect(resumed.phase == .playing)
        #expect(resumed.viewer == .red)
        #expect(resumed.state?.history == c.state?.history)
        #expect(resumed.mode == c.mode)
    }

    @Test func aDamagedSaveIsDiscardedInsteadOfCrashing() throws {
        let url = GameController.saveURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Not JSON at all.
        try Data("not a saved game".utf8).write(to: url)
        #expect(!GameController.hasSave)
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), "the damaged file is removed")

        // Valid JSON describing an impossible board (one square missing).
        let c = computerGame()
        c.confirmDeployment()
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var state = try #require(json["state"] as? [String: Any])
        state["squares"] = (state["squares"] as! [Any]).dropLast().map { $0 }
        json["state"] = state
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        #expect(GameController.resume() == nil)
        #expect(!GameController.hasSave)
    }

    // MARK: Pass and play

    @Test func passAndPlayHandsThePhoneOverAtEveryStep() {
        let c = GameController(mode: .passAndPlay, rules: .standard)
        #expect(c.phase == .deploying(.red))
        c.confirmDeployment()
        #expect(c.phase == .handoff(.blue))
        c.acceptHandoff()
        #expect(c.phase == .deploying(.blue) && c.viewer == .blue)
        c.confirmDeployment()
        #expect(c.phase == .handoff(.red))
        c.acceptHandoff()
        #expect(c.phase == .playing && c.viewer == .red && c.canMove)

        _ = playFirstLegalMove(c)
        #expect(c.phase == .turnComplete)
        #expect(!c.canMove)
        #expect(c.announcement?.viewer == .red)
        c.endTurn()
        #expect(c.phase == .handoff(.blue))
        c.acceptHandoff()
        #expect(c.phase == .playing && c.viewer == .blue && c.canMove)
        // Blue is told about Red's move from Blue's side of the table.
        #expect(c.announcement?.viewer == .blue && c.announcement?.record.side == .red)
    }

    @Test func passAndPlayResumesAtAHandoff() {
        let c = GameController(mode: .passAndPlay, rules: .standard)
        c.confirmDeployment(); c.acceptHandoff(); c.confirmDeployment(); c.acceptHandoff()
        _ = playFirstLegalMove(c)
        let resumed = try! #require(GameController.resume())
        #expect(resumed.phase == .handoff(.blue))
        GameController.deleteSave()
    }

    // MARK: Announcements

    @Test func announcementToneMatchesTheNews() {
        func tone(_ outcome: Outcome, mover: Side) -> Announcement.Tone {
            Announcement(record: PublicMoveRecord(side: mover, move: Move(notation: "a6-a7")!, attackerID: 1, defenderID: 2,
                                                  outcome: outcome, revealedFlags: []), viewer: .red).tone
        }
        #expect(tone(.attackerWon, mover: .red) == .good)
        #expect(tone(.attackerWon, mover: .blue) == .bad)
        #expect(tone(.defenderWon, mover: .red) == .bad)
        #expect(tone(.defenderWon, mover: .blue) == .good)
        #expect(tone(.flagCaptured, mover: .red) == .good)
        #expect(tone(.bothRemoved, mover: .red) == .neutral)
        #expect(tone(.moved, mover: .blue) == .neutral)
    }
}
