import Foundation
import LuzhanqiKit
import Observation

enum GameMode: Codable, Hashable {
    case computer(human: Side, difficulty: Difficulty)
    case passAndPlay
}

enum Phase: Equatable {
    /// `Side` is arranging its army.
    case deploying(Side)
    /// The board is hidden until `Side` takes the phone.
    case handoff(Side)
    case playing
    /// Pass-and-play: the mover sees the result before handing the phone over.
    case turnComplete
    case over
}

/// The last move, as told to `viewer`. Views word it with `Strings`, so it
/// follows the chosen language.
struct Announcement: Identifiable, Equatable {
    enum Tone { case good, bad, neutral }
    let id = UUID()
    let record: PublicMoveRecord
    let viewer: Side

    /// Whether the move was good or bad news for the viewer.
    var tone: Tone {
        let mine = record.side == viewer
        switch record.outcome {
        case .attackerWon, .flagCaptured: return mine ? .good : .bad
        case .defenderWon: return mine ? .bad : .good
        case .moved, .bothRemoved: return .neutral
        }
    }
}

/// Drives one game: deployment, turn order, hot-seat handoffs, the computer
/// opponent, and autosave. Views read the board only through `playerView`,
/// so whatever is on screen is exactly what the current viewer may know.
@MainActor @Observable
final class GameController: Identifiable {
    let mode: GameMode
    let rules: RuleOptions
    private(set) var phase: Phase
    private(set) var state: GameState?
    /// The side whose eyes the screen currently shows.
    private(set) var viewer: Side
    private(set) var aiThinking = false
    private(set) var announcement: Announcement?

    /// The arrangement being edited during `.deploying`.
    private(set) var draft: Deployment
    private(set) var setupViolation: SetupViolation?
    var selected: Position?

    private var deployments: [Side: Deployment] = [:]
    private var rng = SystemRandomNumberGenerator()

    init(mode: GameMode, rules: RuleOptions) {
        self.mode = mode
        self.rules = rules
        var rng = SystemRandomNumberGenerator()
        let first: Side
        let computerDeployment: Deployment?
        switch mode {
        case let .computer(human, difficulty):
            first = human
            computerDeployment = AIPlayer(difficulty: difficulty).deployment(for: human.opponent, using: &rng)
        case .passAndPlay:
            first = .red
            computerDeployment = nil
        }
        viewer = first
        phase = .deploying(first)
        draft = Setup.random(for: first, using: &rng)
        if let computerDeployment { deployments[first.opponent] = computerDeployment }
    }

    var humanSide: Side? {
        if case let .computer(human, _) = mode { return human }
        return nil
    }

    var playerView: PlayerView? { state.map { PlayerView($0, viewer: viewer) } }

    /// True when a tap on the board can make a move.
    var canMove: Bool { phase == .playing && !aiThinking && state?.sideToMove == viewer }

    // MARK: Deployment

    /// Squares the selected piece could legally swap with.
    var swapTargets: Set<Position> {
        guard case let .deploying(side) = phase, let selected else { return [] }
        return Set(draft.keys.filter { $0 != selected && (try? Setup.swapping(selected, $0, in: draft, for: side).get()) != nil })
    }

    func tapDeployment(_ position: Position) {
        guard case let .deploying(side) = phase else { return }
        setupViolation = nil
        guard let first = selected else {
            if draft[position] != nil { selected = position }
            return
        }
        selected = nil
        guard first != position, draft[position] != nil else { return }
        switch Setup.swapping(first, position, in: draft, for: side) {
        case let .success(swapped): draft = swapped
        case let .failure(violation): setupViolation = violation
        }
    }

    func shuffleDraft() {
        guard case let .deploying(side) = phase else { return }
        draft = Setup.random(for: side, using: &rng)
        selected = nil
        setupViolation = nil
    }

    /// A classic defensive layout (the one the Hard computer uses).
    func suggestDraft() {
        guard case let .deploying(side) = phase else { return }
        draft = AIPlayer(difficulty: .hard).deployment(for: side, using: &rng)
        selected = nil
        setupViolation = nil
    }

    func confirmDeployment() {
        guard case let .deploying(side) = phase, Setup.errors(in: draft, for: side).isEmpty else { return }
        deployments[side] = draft
        selected = nil
        if deployments[side.opponent] == nil {
            phase = .handoff(side.opponent)
            return
        }
        guard let red = deployments[.red], let blue = deployments[.blue],
              let game = try? GameState(red: red, blue: blue, rules: rules) else { return }
        state = game
        switch mode {
        case let .computer(human, _):
            phase = .playing
            if game.sideToMove != human { runComputer() }
        case .passAndPlay:
            phase = .handoff(game.sideToMove)
        }
        save()
    }

    func acceptHandoff() {
        guard case let .handoff(side) = phase else { return }
        viewer = side
        announcement = nil
        if state == nil {
            draft = Setup.random(for: side, using: &rng)
            phase = .deploying(side)
        } else {
            phase = .playing
            if let last = playerView?.history.last { announcement = Announcement(record: last, viewer: viewer) }
        }
    }

    // MARK: Play

    func tapBoard(_ position: Position) {
        guard canMove, let view = playerView else { return }
        if let selected, view.destinations(from: selected).contains(position) {
            play(Move(selected, position))
        } else if view[position]?.side == viewer, !view.destinations(from: position).isEmpty {
            selected = selected == position ? nil : position
        } else {
            selected = nil
        }
    }

    private func play(_ move: Move) {
        guard var game = state, (try? game.apply(move)) != nil else { return }
        state = game
        selected = nil
        afterMove()
    }

    private func afterMove() {
        guard let state else { return }
        if let last = playerView?.history.last { announcement = Announcement(record: last, viewer: viewer) }
        if state.isOver {
            phase = .over
            Self.deleteSave()
            return
        }
        save()
        switch mode {
        case let .computer(human, _):
            if state.sideToMove != human { runComputer() }
        case .passAndPlay:
            phase = .turnComplete
        }
    }

    /// Pass-and-play: hide the board and hand over to the next player.
    func endTurn() {
        guard phase == .turnComplete, let state else { return }
        selected = nil
        phase = .handoff(state.sideToMove)
    }

    func resign() {
        guard var game = state, !game.isOver else { return }
        game.resign(humanSide ?? game.sideToMove)
        state = game
        phase = .over
        Self.deleteSave()
    }

    private func runComputer() {
        guard case let .computer(human, difficulty) = mode, let state else { return }
        let view = PlayerView(state, viewer: human.opponent)
        aiThinking = true
        Task {
            let started = ContinuousClock.now
            let move = await Task.detached(priority: .userInitiated) {
                var rng = SystemRandomNumberGenerator()
                return AIPlayer(difficulty: difficulty).chooseMove(view, using: &rng)
            }.value
            // A beat of "thinking" so instant replies don't feel abrupt.
            let pause = Duration.milliseconds(450) - (ContinuousClock.now - started)
            if pause > .zero { try? await Task.sleep(for: pause) }
            aiThinking = false
            guard let move, var game = self.state, game.sideToMove == human.opponent,
                  (try? game.apply(move)) != nil else { return }
            self.state = game
            afterMove()
        }
    }

    // MARK: Autosave

    private struct SavedGame: Codable {
        let mode: GameMode
        let state: GameState
    }

    static var saveURL: URL {
        URL.applicationSupportDirectory.appending(path: "SavedGame.json")
    }

    private func save() {
        guard let state, !state.isOver else { return }
        do {
            try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(SavedGame(mode: mode, state: state)).write(to: Self.saveURL, options: .atomic)
        } catch {
            print("Autosave failed: \(error)")
        }
    }

    static func deleteSave() {
        try? FileManager.default.removeItem(at: saveURL)
    }

    /// Whether there is a saved game that can be resumed.
    static var hasSave: Bool { loadSave() != nil }

    /// The autosaved game in progress, if any.
    static func resume() -> GameController? {
        loadSave().map(GameController.init(saved:))
    }

    /// Reads the save, discarding it if it is unreadable, finished, or doesn't
    /// describe a possible game (a damaged or edited file must not crash the app).
    private static func loadSave() -> SavedGame? {
        guard let data = try? Data(contentsOf: saveURL) else { return nil }
        guard let saved = try? JSONDecoder().decode(SavedGame.self, from: data),
              saved.state.isWellFormed, !saved.state.isOver else {
            deleteSave()
            return nil
        }
        return saved
    }

    private init(saved: SavedGame) {
        mode = saved.mode
        rules = saved.state.rules
        state = saved.state
        draft = [:]
        switch saved.mode {
        case let .computer(human, _):
            viewer = human
            phase = .playing
            if saved.state.sideToMove != human { runComputer() }
        case .passAndPlay:
            viewer = saved.state.sideToMove
            phase = .handoff(saved.state.sideToMove)
        }
    }
}

#if DEBUG
extension GameController {
    /// Opens straight onto one screen for screenshots and UI review, since the
    /// Simulator can't be tapped from the command line. Launch with
    /// `-demo deploy|deploy-error|handoff|turn|game|over` (and `rules` or `settings`, handled by ContentView).
    static func demo(_ screen: String) -> GameController? {
        var rng = SeededGenerator(seed: 42)
        let mode = GameMode.computer(human: .red, difficulty: .medium)
        switch screen {
        case "deploy":
            let controller = GameController(mode: mode, rules: .standard)
            controller.selected = controller.draft.first { $0.value == .general }?.key
            return controller
        case "deploy-error":
            // The longest English setup message, to check the hint area doesn't grow.
            let controller = GameController(mode: mode, rules: .standard)
            controller.setupViolation = .landmineOutsideBackRows
            return controller
        case "turn":
            // Pass-and-play, just after Red's move: the "Done — pass to Blue" button.
            let controller = GameController(mode: .passAndPlay, rules: .standard)
            controller.confirmDeployment(); controller.acceptHandoff(); controller.confirmDeployment(); controller.acceptHandoff()
            if let move = controller.playerView?.legalMoves().first(where: { controller.playerView?[$0.to] != nil }) {
                controller.tapBoard(move.from); controller.tapBoard(move.to)
            }
            return controller
        case "handoff":
            let controller = GameController(mode: .passAndPlay, rules: .standard)
            controller.confirmDeployment()
            return controller
        case "game", "over":
            let ai = AIPlayer(difficulty: .easy)
            var state = try! GameState(red: AIPlayer(difficulty: .hard).deployment(for: .red, using: &rng),
                                       blue: AIPlayer(difficulty: .hard).deployment(for: .blue, using: &rng))
            let plies = screen == "over" ? Int.max : 30
            var played = 0
            while played < plies && !state.isOver {
                try! state.apply(ai.chooseMove(PlayerView(state, viewer: state.sideToMove), using: &rng)!)
                played += 1
            }
            let controller = GameController(saved: SavedGame(mode: mode, state: state))
            if state.isOver {
                controller.phase = .over
            } else {
                controller.selected = Board.allPositions.first {
                    state[$0]?.side == .red && state.destinations(from: $0).count >= 3
                }
            }
            if let last = controller.playerView?.history.last { controller.announcement = Announcement(record: last, viewer: controller.viewer) }
            return controller
        default:
            return nil
        }
    }
}
#endif
