extension GameState {
    /// Every legal move for `side` (the side to move by default).
    public func legalMoves(for side: Side? = nil) -> [Move] {
        let side = side ?? sideToMove
        var moves: [Move] = []
        for f in 0..<Board.count where squares[f]?.side == side {
            let from = Position(index: f)
            for t in destinationIndices(from: f) { moves.append(Move(from, Position(index: t))) }
        }
        return moves
    }

    /// Squares the piece on `position` can move to or attack.
    public func destinations(from position: Position) -> [Position] {
        destinationIndices(from: position.index).map(Position.init(index:))
    }

    func hasLegalMove(_ side: Side) -> Bool {
        (0..<Board.count).contains { squares[$0]?.side == side && !destinationIndices(from: $0).isEmpty }
    }

    /// Destination indices, ascending. Board.count is 60, so a UInt64 mask
    /// doubles as the visited set.
    func destinationIndices(from f: Int) -> [Int] {
        guard let piece = squares[f], piece.rank.isMovable, Board.stations[f] != .headquarters else { return [] }
        var targets: UInt64 = 0
        for n in Board.road[f] where canEnter(piece.side, n) { targets |= 1 << n }
        if Board.isRail[f] {
            targets |= piece.rank == .engineer ? engineerRailTargets(from: f, side: piece.side)
                                               : straightRailTargets(from: f, side: piece.side)
        }
        var result: [Int] = []
        while targets != 0 {
            let i = targets.trailingZeroBitCount
            result.append(i)
            targets &= targets - 1
        }
        return result
    }

    private func canEnter(_ side: Side, _ i: Int) -> Bool {
        guard let occupant = squares[i] else { return true }
        return occupant.side != side && Board.stations[i] != .camp
    }

    private func straightRailTargets(from f: Int, side: Side) -> UInt64 {
        var targets: UInt64 = 0
        for line in Board.railLinesThrough[f] {
            let start = line.firstIndex(of: f)!
            for step in [-1, 1] {
                var j = start + step
                while line.indices.contains(j) {
                    let n = line[j]
                    if squares[n] != nil {
                        if canEnter(side, n) { targets |= 1 << n }
                        break
                    }
                    targets |= 1 << n
                    j += step
                }
            }
        }
        return targets
    }

    /// Engineers may follow any railroad path through empty squares.
    private func engineerRailTargets(from f: Int, side: Side) -> UInt64 {
        var targets: UInt64 = 0
        var seen: UInt64 = 1 << f
        var queue = [f]
        var head = 0
        while head < queue.count {
            let i = queue[head]
            head += 1
            for n in Board.rail[i] where seen & (1 << n) == 0 {
                seen |= 1 << n
                if squares[n] != nil {
                    if canEnter(side, n) { targets |= 1 << n }
                } else {
                    targets |= 1 << n
                    queue.append(n)
                }
            }
        }
        return targets
    }
}
