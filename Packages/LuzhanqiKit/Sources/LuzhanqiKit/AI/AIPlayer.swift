public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy
    case medium
    case hard

    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// A computer opponent. It decides from a `PlayerView` only, so it plays by the
/// same hidden-information rules as a human.
///
/// - Easy: a one-move heuristic with plenty of randomness.
/// - Medium / Hard: determinized search. Each sample guesses every hidden enemy
///   rank consistently with `Beliefs`, then scores each of our moves by the
///   opponent's best reply. Scores are averaged over samples. Hard uses many
///   more samples and no added noise.
public struct AIPlayer: Sendable {
    public let difficulty: Difficulty
    /// Maximum determinizations per move.
    public var samples: Int
    /// Stop sampling after this long (at least `minimumSamples` always run).
    public var timeBudget: Duration
    public var minimumSamples = 3
    /// Random noise added to move scores; makes Medium beatable.
    var noise: Double

    public init(difficulty: Difficulty) {
        self.difficulty = difficulty
        switch difficulty {
        case .easy: (samples, timeBudget, noise) = (0, .zero, 0)
        case .medium: (samples, timeBudget, noise) = (6, .milliseconds(400), 12)
        case .hard: (samples, timeBudget, noise) = (48, .milliseconds(1500), 0)
        }
    }

    public func deployment(for side: Side, using rng: inout some RandomNumberGenerator) -> Deployment {
        AIDeployer.deployment(for: side, difficulty: difficulty, using: &rng)
    }

    /// The move to play, or nil if it is not the viewer's turn or there is none.
    public func chooseMove(_ view: PlayerView, using rng: inout some RandomNumberGenerator) -> Move? {
        let moves = view.legalMoves()
        guard moves.count > 1 else { return moves.first }
        let beliefs = Beliefs(view)
        let scores = difficulty == .easy
            ? heuristicScores(moves, view: view, beliefs: beliefs, using: &rng)
            : searchScores(moves, view: view, beliefs: beliefs, using: &rng)
        let best = scores.max()!
        let candidates = moves.indices.filter { scores[$0] >= best - 1e-9 }
        return moves[candidates.randomElement(using: &rng)!]
    }

    // MARK: Easy

    private func heuristicScores(_ moves: [Move], view: PlayerView, beliefs: Beliefs,
                                 using rng: inout some RandomNumberGenerator) -> [Double] {
        moves.map { move in
            let mine = view[move.from]!.rank!
            var score = Double.random(in: 0..<10, using: &rng)
            if let target = view[move.to] {
                let outcomes = beliefs.possibleRanks(of: target.id).map {
                    Combat.resolve(attacker: mine, defender: $0, rules: view.rules)
                }
                let n = Double(outcomes.count)
                let wins = Double(outcomes.filter { $0 == .attackerWon || $0 == .flagCaptured }.count)
                let losses = Double(outcomes.filter { $0 == .defenderWon }.count)
                if outcomes.allSatisfy({ $0 == .flagCaptured }) {
                    score += 1000
                } else if losses == n {
                    score -= 100
                } else if wins == n {
                    score += 40
                } else {
                    score += 15 * (wins - losses) / n
                }
            } else {
                let advance = Board.localRow(view.viewer, move.to) - Board.localRow(view.viewer, move.from)
                score += 2 * Double(advance)
            }
            return score
        }
    }

    // MARK: Medium / Hard

    private func searchScores(_ moves: [Move], view: PlayerView, beliefs: Beliefs,
                              using rng: inout some RandomNumberGenerator) -> [Double] {
        let clock = ContinuousClock()
        let deadline = clock.now + timeBudget
        var totals = [Double](repeating: 0, count: moves.count)
        var completed = 0
        while completed < max(samples, 1) && (completed < minimumSamples || clock.now < deadline) {
            let state = view.determinized(assigning: beliefs.sample(using: &rng))
            for (k, move) in moves.enumerated() {
                totals[k] += valueAfterReply(move, in: state, for: view.viewer)
            }
            completed += 1
        }
        return totals.map { $0 / Double(completed) + Double.random(in: 0...noise, using: &rng) }
    }

    /// Evaluation for `side` after playing `move` and the opponent's best reply.
    func valueAfterReply(_ move: Move, in state: GameState, for side: Side) -> Double {
        var afterMove = state
        afterMove.perform(from: move.from.index, to: move.to.index)
        if afterMove.isOver { return Evaluator.score(afterMove, for: side) }
        var worst = Double.infinity
        for f in 0..<Board.count where afterMove.squares[f]?.side == side.opponent {
            for t in afterMove.destinationIndices(from: f) {
                var afterReply = afterMove
                afterReply.perform(from: f, to: t)
                worst = min(worst, Evaluator.score(afterReply, for: side))
                if worst <= -Evaluator.winScore { return worst }
            }
        }
        return worst.isFinite ? worst : Evaluator.score(afterMove, for: side)
    }
}
