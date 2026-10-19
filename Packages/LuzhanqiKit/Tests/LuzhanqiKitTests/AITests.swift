import Testing
@testable import LuzhanqiKit

@Suite struct BeliefsTests {
    /// Blue pieces start on their deployment squares (ids = square index), so
    /// Beliefs can apply the setup rules to them.
    func blueView(_ state: GameState) -> Beliefs { Beliefs(PlayerView(state, viewer: .red)) }

    @Test func setupRulesConstrainUnmovedPieces() {
        let state = game(flags.with(["a7": (.blue, .captain), "d12": (.blue, .landmine), "e2": (.red, .colonel)]))
        let beliefs = blueView(state)
        #expect(!beliefs.possibleRanks(of: pos("a7").index).contains(.bomb))      // front row
        #expect(!beliefs.possibleRanks(of: pos("a7").index).contains(.landmine))
        #expect(beliefs.possibleRanks(of: pos("d12").index).contains(.flag))     // headquarters
    }

    @Test func movingRulesOutMinesAndFlags() throws {
        var state = game(flags.with(["e2": (.red, .colonel), "a11": (.blue, .captain)]))
        try state.apply(move("e2-e3"))
        try state.apply(move("a11-b11"))
        let ranks = blueView(state).possibleRanks(of: pos("a11").index)
        #expect(!ranks.contains(.landmine) && !ranks.contains(.flag))
    }

    @Test func turningARailCornerMeansEngineer() throws {
        var state = game(flags.with(["e2": (.red, .colonel), "c7": (.blue, .engineer)]))
        try state.apply(move("e2-e3"))
        try state.apply(move("c7-a9"))  // c7 → a7 → a9 needs a turn
        #expect(blueView(state).knownRank(of: pos("c7").index) == .engineer)
    }

    @Test func battleResultsNarrowRanks() throws {
        // Blue's piece beats our Captain: it must be a stronger officer.
        var state = game(flags.with(["a6": (.red, .captain), "a7": (.blue, .colonel), "e2": (.red, .major), "e11": (.blue, .lieutenant)]))
        try state.apply(move("a6-a7"))
        let ranks = blueView(state).possibleRanks(of: pos("a7").index)
        #expect(Set(ranks) == [.fieldMarshal, .general, .majorGeneral, .brigadier, .colonel, .major])

        // A trade with our Captain: a Captain or a Bomb (it started behind the
        // front row, where bombs may deploy).
        var trade = game(flags.with(["a6": (.red, .captain), "a8": (.blue, .captain), "e2": (.red, .major), "e11": (.blue, .lieutenant)]))
        try trade.apply(move("a6-a8"))
        #expect(Set(blueView(trade).possibleRanks(of: pos("a8").index)) == [.captain, .bomb])
    }

    @Test func samplesRespectBeliefsAndCounts() throws {
        var rng = SeededGenerator(seed: 9)
        var state = try GameState(red: Setup.random(for: .red, using: &rng), blue: Setup.random(for: .blue, using: &rng))
        for _ in 0..<30 where !state.isOver { try state.apply(state.legalMoves().randomElement(using: &rng)!) }
        let beliefs = Beliefs(PlayerView(state, viewer: .red))
        for _ in 0..<50 {
            let sample = beliefs.sample(using: &rng)
            #expect(sample.count == 25)
            for rank in Rank.allCases { #expect(sample.values.filter { $0 == rank }.count == rank.count) }
            for (id, rank) in sample { #expect(beliefs.possibleRanks(of: id).contains(rank)) }
        }
    }
}

@Suite struct AIPlayerTests {
    @Test(arguments: Difficulty.allCases)
    func deploymentsAreLegal(difficulty: Difficulty) {
        var rng = SeededGenerator(seed: 4)
        for side in Side.allCases {
            for _ in 0..<50 {
                #expect(Setup.errors(in: AIPlayer(difficulty: difficulty).deployment(for: side, using: &rng), for: side).isEmpty)
            }
        }
    }

    @Test(arguments: Difficulty.allCases)
    func takesARevealedFlag(difficulty: Difficulty) throws {
        var state = game(flags.with([
            "a6": (.red, .bomb), "a7": (.blue, .fieldMarshal),
            "b11": (.red, .lieutenant), "c11": (.blue, .colonel), "e2": (.red, .colonel),
        ]))
        try state.apply(move("a6-a7"))  // marshal dies, Blue's flag is revealed
        try state.apply(move("c11-c10"))
        var rng = SeededGenerator(seed: 1)
        let choice = AIPlayer(difficulty: difficulty).chooseMove(PlayerView(state, viewer: .red), using: &rng)
        #expect(choice == move("b11-b12"))
    }

    @Test func easyAvoidsKnownLosingAttacks() throws {
        // Blue's piece is known to be stronger than a Captain after beating one.
        var state = game(flags.with([
            "a6": (.red, .captain), "b6": (.red, .lieutenant), "a7": (.blue, .general),
            "e2": (.red, .major), "e11": (.blue, .lieutenant),
        ]))
        try state.apply(move("a6-a7"))
        try state.apply(move("a7-a6"))  // the General walks into a lieutenant's reach
        let view = PlayerView(state, viewer: .red)
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<20 {
            #expect(AIPlayer(difficulty: .easy).chooseMove(view, using: &rng) != move("b6-a6"))
        }
    }

    @Test func selfPlayIsLegalAndHardBeatsEasy() throws {
        var hard = AIPlayer(difficulty: .hard)
        hard.samples = 6
        hard.timeBudget = .milliseconds(100)
        let easy = AIPlayer(difficulty: .easy)
        var hardWins = 0
        var easyWins = 0
        let games = 8
        for seed in 0..<games {
            var rng = SeededGenerator(seed: UInt64(seed))
            let hardSide: Side = seed.isMultiple(of: 2) ? .red : .blue
            let players: [Side: AIPlayer] = [hardSide: hard, hardSide.opponent: easy]
            var state = try GameState(red: players[.red]!.deployment(for: .red, using: &rng),
                                      blue: players[.blue]!.deployment(for: .blue, using: &rng))
            var plies = 0
            while !state.isOver && plies < 400 {
                let side = state.sideToMove
                let choice = players[side]!.chooseMove(PlayerView(state, viewer: side), using: &rng)
                try state.apply(#require(choice))
                plies += 1
            }
            if state.result?.winner == hardSide { hardWins += 1 }
            if state.result?.winner == hardSide.opponent { easyWins += 1 }
        }
        print("Hard \(hardWins) – Easy \(easyWins) – other \(games - hardWins - easyWins)")
        #expect(hardWins > easyWins)
    }
}
