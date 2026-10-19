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

/// A saved game is read back from disk, so a damaged or edited file must be
/// rejected rather than crash the app.
@Suite struct SaveValidationTests {
    func newGame() throws -> GameState {
        var rng = SeededGenerator(seed: 21)
        return try GameState(red: Setup.random(for: .red, using: &rng), blue: Setup.random(for: .blue, using: &rng))
    }

    /// Re-encodes `state` after editing its JSON.
    func tampered(_ state: GameState, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        edit(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test func realGamesAreWellFormed() throws {
        var state = try newGame()
        #expect(state.isWellFormed)
        var rng = SeededGenerator(seed: 4)
        for _ in 0..<50 where !state.isOver { try state.apply(state.legalMoves().randomElement(using: &rng)!) }
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        #expect(decoded.isWellFormed)
    }

    @Test func offBoardSquaresAreRejected() throws {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Position.self, from: Data(#"{"row":12,"col":0}"#.utf8)) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Position.self, from: Data(#"{"row":0,"col":-1}"#.utf8)) }
        #expect(try JSONDecoder().decode(Position.self, from: Data(#"{"row":11,"col":4}"#.utf8)) == Position(name: "e1"))
    }

    @Test func aShortBoardIsRejected() throws {
        let data = try tampered(try newGame()) { json in json["squares"] = (json["squares"] as! [Any]).dropLast().map { $0 } }
        #expect(try JSONDecoder().decode(GameState.self, from: data).isWellFormed == false)
    }

    @Test func impossibleArmiesAreRejected() throws {
        let state = try newGame()
        // Turn every Red piece into a Flag: far more Flags than an army has.
        let flags = try tampered(state) { json in
            json["squares"] = (json["squares"] as! [Any]).map { square -> Any in
                guard var piece = square as? [String: Any], piece["side"] as? String == "red" else { return square }
                piece["rank"] = Rank.flag.rawValue
                return piece
            }
        }
        #expect(try JSONDecoder().decode(GameState.self, from: flags).isWellFormed == false)
        // Give two pieces the same id.
        let duplicate = try tampered(state) { json in
            var squares = json["squares"] as! [Any]
            let first = squares.firstIndex { $0 is [String: Any] }!
            let second = squares[(first + 1)...].firstIndex { $0 is [String: Any] }!
            var piece = squares[second] as! [String: Any]
            piece["id"] = (squares[first] as! [String: Any])["id"]
            squares[second] = piece
            json["squares"] = squares
        }
        #expect(try JSONDecoder().decode(GameState.self, from: duplicate).isWellFormed == false)
    }
}
