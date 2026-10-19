import Testing
@testable import LuzhanqiKit

@Suite struct CombatTests {
    /// Red's piece on a6 attacks Blue's piece on a7.
    func battle(_ attacker: Rank, _ defender: Rank, rules: RuleOptions = .standard) throws -> (GameState, MoveRecord) {
        var state = game(flags.with([
            "a6": (.red, attacker), "a7": (.blue, defender),
            "e2": (.red, .lieutenant), "e11": (.blue, .lieutenant),  // keep both sides mobile
        ]), rules: rules)
        let record = try state.apply(move("a6-a7"))
        return (state, record)
    }

    @Test func higherRankWins() throws {
        let (state, record) = try battle(.general, .colonel)
        #expect(record.outcome == .attackerWon)
        #expect(state[pos("a7")]?.rank == .general)
        #expect(state[pos("a6")] == nil)

        let (state2, record2) = try battle(.captain, .major)
        #expect(record2.outcome == .defenderWon)
        #expect(state2[pos("a7")]?.rank == .major)
        #expect(state2[pos("a6")] == nil)
    }

    @Test func equalRanksBothDie() throws {
        let (state, record) = try battle(.captain, .captain)
        #expect(record.outcome == .bothRemoved)
        #expect(state[pos("a7")] == nil)
    }

    @Test(arguments: [Rank.fieldMarshal, .engineer, .bomb, .landmine])
    func bombsTakeEverythingWithThem(other: Rank) throws {
        let (state, record) = try battle(.bomb, other)
        #expect(record.outcome == .bothRemoved)
        #expect(state[pos("a7")] == nil)
        if other.isMovable {
            let (_, reverse) = try battle(other, .bomb)
            #expect(reverse.outcome == .bothRemoved)
        }
    }

    @Test func landmines() throws {
        let (state, record) = try battle(.fieldMarshal, .landmine)
        #expect(record.outcome == .defenderWon)
        #expect(state[pos("a7")]?.rank == .landmine)

        let (cleared, engineer) = try battle(.engineer, .landmine)
        #expect(engineer.outcome == .attackerWon)
        #expect(cleared[pos("a7")]?.rank == .engineer)

        let (exploded, explosive) = try battle(.general, .landmine, rules: RuleOptions(explosiveMines: true))
        #expect(explosive.outcome == .bothRemoved)
        #expect(exploded[pos("a7")] == nil)
    }

    @Test func capturingTheFlagWins() throws {
        let (state, record) = try battle(.engineer, .flag)
        #expect(record.outcome == .flagCaptured)
        #expect(state.result == .win(.red, .flagCaptured))
        #expect(state.isOver)
    }

    @Test func losingTheFieldMarshalRevealsTheFlag() throws {
        let (state, record) = try battle(.fieldMarshal, .fieldMarshal)
        #expect(record.revealedFlags == [.red, .blue])
        #expect(state.flagRevealed == [.red, .blue])

        let (bombed, _) = try battle(.bomb, .fieldMarshal)
        #expect(bombed.flagRevealed == [.blue])
        #expect(PlayerView(bombed, viewer: .red)[pos("b12")]?.rank == .flag)
        #expect(PlayerView(bombed, viewer: .red)[pos("e11")]?.rank == nil)
    }

    @Test func capturingTheWrongHeadquartersRevealsTheFlag() throws {
        var state = game(flags.with([
            "d11": (.red, .general), "d12": (.blue, .captain), "e2": (.red, .lieutenant), "e11": (.blue, .lieutenant),
        ]))
        let record = try state.apply(move("d11-d12"))
        #expect(record.outcome == .attackerWon)
        #expect(state.flagRevealed == [.blue])
        #expect(state.destinations(from: pos("d12")).isEmpty)  // stuck in the headquarters
    }

    @Test func sideWithNoMovesLoses() throws {
        var state = game(flags.with(["a6": (.red, .captain), "a7": (.blue, .general), "e11": (.blue, .lieutenant)]))
        try state.apply(move("a6-a7"))  // Red's last mobile piece dies
        #expect(state.result == nil)
        try state.apply(move("e11-e10"))
        #expect(state.result == .win(.blue, .opponentCannotMove))
    }

    @Test func neitherSideCanMoveIsADraw() throws {
        var state = game(flags.with(["a6": (.red, .colonel), "a7": (.blue, .colonel)]))
        try state.apply(move("a6-a7"))
        #expect(state.result == .draw(.neitherSideCanMove))
    }

    @Test func noBattleLimitDraws() throws {
        var state = game(flags.with(["a4": (.red, .colonel), "a10": (.blue, .colonel)]),
                         rules: RuleOptions(noBattleDrawLimit: 3))
        try state.apply(move("a4-a5"))
        try state.apply(move("a10-a9"))
        #expect(state.result == nil)
        try state.apply(move("a5-a4"))
        #expect(state.result == .draw(.noBattleLimit))
        #expect(throws: GameError.gameOver) { try state.apply(move("a9-a10")) }
    }
}
