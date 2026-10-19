import Foundation
import Testing
@testable import LuzhanqiKit

@Suite struct PlayerViewTests {
    func newGame(seed: UInt64, rules: RuleOptions = .standard) throws -> GameState {
        var rng = SeededGenerator(seed: seed)
        return try GameState(red: Setup.random(for: .red, using: &rng),
                             blue: Setup.random(for: .blue, using: &rng), rules: rules)
    }

    @Test func hidesEnemyRanks() throws {
        let state = try newGame(seed: 7)
        let view = PlayerView(state, viewer: .red)
        for p in Board.allPositions {
            guard let piece = view[p] else { continue }
            #expect((piece.rank != nil) == (piece.side == .red))
        }
    }

    @Test func openModeShowsEverything() throws {
        let state = try newGame(seed: 7, rules: RuleOptions(openPieces: true))
        #expect(PlayerView(state, viewer: .red).squares.compactMap { $0 }.allSatisfy { $0.rank != nil })
    }

    @Test func viewerMovesMatchTheTrueState() throws {
        var state = try newGame(seed: 11)
        var rng = SeededGenerator(seed: 3)
        for _ in 0..<40 where !state.isOver {
            let side = state.sideToMove
            #expect(Set(PlayerView(state, viewer: side).legalMoves()) == Set(state.legalMoves()))
            #expect(PlayerView(state, viewer: side.opponent).legalMoves().isEmpty)
            try state.apply(state.legalMoves().randomElement(using: &rng)!)
        }
    }

    @Test func gameStateRoundTripsThroughJSON() throws {
        var state = try newGame(seed: 5)
        try state.apply(state.legalMoves()[0])
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        #expect(decoded.squares == state.squares)
        #expect(decoded.history == state.history)
        #expect(decoded.sideToMove == state.sideToMove)
    }
}
