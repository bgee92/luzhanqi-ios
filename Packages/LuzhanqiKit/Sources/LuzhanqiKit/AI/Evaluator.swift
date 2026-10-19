/// Static evaluation of a fully known (determinized) position.
enum Evaluator {
    static let winScore = 100_000.0

    /// Material value by `Rank.rawValue`. Engineers and bombs are worth more
    /// than their combat power: engineers are the only way through a minefield,
    /// and a bomb can trade for anything.
    static let pieceValue: [Double] = [100, 80, 60, 45, 33, 24, 16, 11, 22, 50, 18, 0]

    /// Higher is better for `side`.
    static func score(_ state: GameState, for side: Side) -> Double {
        if let result = state.result {
            if case let .win(winner, _) = result { return winner == side ? winScore : -winScore }
            return 0
        }
        var ownFlag = -1
        var enemyFlag = -1
        for i in 0..<Board.count {
            guard let piece = state.squares[i], piece.rank == .flag else { continue }
            if piece.side == side { ownFlag = i } else { enemyFlag = i }
        }

        var score = 0.0
        var nearestThreat = Int.max  // enemy attacker closest to our flag
        var nearestAttack = Int.max  // our attacker closest to theirs
        for i in 0..<Board.count {
            guard let piece = state.squares[i] else { continue }
            let mine = piece.side == side
            let sign = mine ? 1.0 : -1.0
            score += sign * pieceValue[piece.rank.rawValue]

            guard piece.rank.isMovable, Board.stations[i] != .headquarters else { continue }
            // Pressure on the enemy flag.
            let target = mine ? enemyFlag : ownFlag
            if target >= 0 {
                let d = Board.moveDistance[i][target]
                score += sign * 0.6 * Double(max(0, 8 - d))
                if mine { nearestAttack = min(nearestAttack, d) } else { nearestThreat = min(nearestThreat, d) }
            }
            // A camp in enemy territory is a safe forward base.
            if Board.stations[i] == .camp && Board.half(of: Position(index: i)) != piece.side {
                score += sign * 3
            }
        }
        if nearestThreat <= 2 { score -= 25 / Double(nearestThreat) }
        if nearestAttack <= 2 { score += 25 / Double(nearestAttack) }
        return score
    }
}
